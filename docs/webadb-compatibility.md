## Summary

While building a WebUSB-based ADB tool for an e-ink reader with an RK3326 (Rockchip) SoC running Android 11 (FunctionFS-based adbd), I hit **three independent incompatibilities** in `Adb.WebUSB.Transport`. Each one alone makes every connection fail, and their symptoms overlap (all surface as `Failed to execute 'transferOut'/'transferIn' ... A transfer error has occurred`), which made them painful to isolate. All three are confirmed fixed by the patches below, verified end-to-end (CNXN → AUTH → RSA key → shell commands).

Test device: EEGO P4 e-reader, RK3326, Android 11, `mtp,adb` configfs gadget (MTP on interface 0, ADB class FF/42/1 on interface 1, bulk endpoints, maxPacketSize 512). Host: Chrome on macOS. Plain `adb` over USB works flawlessly on the same setup, which makes these bugs easy to miss.

## 1. `Adb.WebUSB.Device` constructor calls `USBDevice.reset()` — knocks RK gadgets off the bus

```js
Adb.WebUSB.Device = function(transport, match) {
    ...
    this.transport.reset();   // == USBDevice.reset()
}
```

On RK3326, a USB port reset makes the gadget **disappear from the bus without self-recovery** — it requires a physical replug (or `adb reboot`). Since this runs on *every* connect, the first data transfer always fails after the device has already dropped. Suggestion: remove the reset, or gate it behind an opt-in / a retry-on-first-transfer-failure.

## 2. `getDevice()` always issues `selectConfiguration()` + `selectAlternateInterface()` — tears down FunctionFS endpoints mid-session

```js
Adb.WebUSB.Transport.prototype.getDevice = function(filter) {
    let match = this.find(filter);
    return this.device.selectConfiguration(match.conf.configurationValue)
        .then(() => this.device.claimInterface(match.intf.interfaceNumber))
        .then(() => this.device.selectAlternateInterface(match.intf.interfaceNumber, match.alt.alternateSetting))
        .then(() => match);
};
```

On this device (already configured when enumerated), re-issuing `SET_CONFIGURATION(1)` and `SET_INTERFACE(alt 0)` causes the configfs gadget to **unbind and rebind the FunctionFS endpoints**. Device-side `adbd` log shows the cycle after every connection attempt:

```
UsbFfs: connection terminated: received packet of unexpected length while reading header
UsbFfs: destroying transport UsbFfs
opening control endpoint /dev/usb-ffs/adb/ep0
USB event: FUNCTIONFS_BIND
USB event: FUNCTIONFS_ENABLE
```

After the rebind, the host-side pipes are stale and every subsequent `transferOut`/`transferIn` fails with "A transfer error has occurred" — even across page reloads (the USB device handle lives in the browser process). Only a fresh USB enumeration (replug/reboot) recovers it. This was the hardest of the three to find.

Suggestion: skip `selectConfiguration` when `device.configuration !== null` (and only set it when actually needed), and skip `selectAlternateInterface` when `alternateSetting === 0`. Claiming alone is sufficient in the already-configured case.

## 3. Single `transferOut` of header+payload is misread by RK adbd

Sending a full ADB packet (24-byte header + payload) in **one** `transferOut` results in the device reading a wrong length: adbd logs `received packet of unexpected length while reading header` and immediately terminates the connection (the host sees the pending `transferIn` fail ~30 ms later). Splitting the same bytes into **two** `transferOut` calls — 24-byte header, then payload — works reliably and matches adbd's read pattern (read 24, then read `data_length`). Raw-protocol probes confirmed: a header-only CNXN gets a proper AUTH reply; a combined 49-byte CNXN kills the connection.

I suspect this is a device-side FunctionFS/dwc2 quirk rather than a webadb bug (it may well be macOS-Chrome's transfer submission path interacting with the gadget's DMA alignment), but an optional "split writes" mode would make webadb.js work on this whole class of Rockchip devices.

## Working patches

All three workarounds are deployed and load-time patched in this project's page (see the patch block right after the `webadb.js` script tag):

- https://github.com/ProLawnMower/EnableTwoBitForEEGOP4/blob/main/docs/index.html

```js
// 1. neutralize the built-in reset
Adb.WebUSB.Transport.prototype.reset = function() {};

// 2. skip selectConfiguration/selectAlternateInterface, claim only
Adb.WebUSB.Transport.prototype.getDevice = function(filter) {
    const match = this.find(filter);
    if (!match) return Promise.reject(new Error("ADB interface not found"));
    return this.device.claimInterface(match.intf.interfaceNumber).then(() => match);
};

// 3. split outgoing packets into header + payload transfers
Adb.WebUSB.Transport.prototype.send = function(ep, data) {
    const dv = data instanceof DataView ? data : new DataView(data.buffer ?? data);
    if (dv.byteLength > 24) {
        const head = dv.buffer.slice(dv.byteOffset, dv.byteOffset + 24);
        const body = dv.buffer.slice(dv.byteOffset + 24, dv.byteOffset + dv.byteLength);
        return this.device.transferOut(ep, head).then(() => this.device.transferOut(ep, body));
    }
    return this.device.transferOut(ep, data);
};
```

Happy to turn these into a PR (e.g. behind an `Adb.Opt` compatibility flag, or auto-detect) if the approach sounds reasonable — just let me know which shape you'd prefer.

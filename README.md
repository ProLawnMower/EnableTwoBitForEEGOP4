# EnableTwoBitForEEGOP4

EEGO P4（及同方案墨水屏阅读器）**显示模式一键切换工具**——三种模式，三种文件形态任选：桌面脚本 / ADB 命令 / 纯浏览器在线版（WebUSB）。

通过设置三个系统属性实现切换，**仅运行时生效、不修改任何系统文件、重启即恢复出厂**，零风险。

## 三种显示模式

| 模式 | 参数 | 效果 |
|---|---|---|
| **锐利** `sharp` | `sys.eink.mode=2` `sys.eink.dither=1` `sys.eink.dither.var_thresh=1000` | 出厂默认。文字纯黑白硬阈值最锐利，快刷不闪，图片为系统网点抖动 |
| **平滑** `smooth` | `sys.eink.mode=2` `sys.eink.dither=1` `sys.eink.dither.var_thresh=100000` | 文字边缘网点化灰阶（粗细均匀、远看平滑），仍保持快刷不闪 |
| **超清** `hd` | `sys.eink.mode=4` `sys.eink.dither=1` `sys.eink.dither.var_thresh=1000` | 真 2-bit 四级灰度（文字+图片真灰阶），代价是每次刷新全屏闪 |

> 属性实时生效，屏幕会随下一次刷新切换；`sys.*` 属性重启后自动回到出厂默认（锐利）。

## 在线版（推荐）：无需安装任何东西

**[→ 打开在线切换器](https://prolawnmower.github.io/EnableTwoBitForEEGOP4/)**

用 **Chrome 或 Edge** 打开上面的页面，USB 连接阅读器：

1. 点「连接设备」→ 浏览器弹出的选择器里选中阅读器
2. 阅读器屏幕上会弹「允许 USB 调试吗？」——**勾选「一律允许」**再点允许（浏览器生成的密钥保存在本机 IndexedDB，之后访问不再弹窗）
3. 点任意模式按钮即完成，页面会实时读回当前模式确认生效

原理：页面通过 **WebUSB** 直接与设备的 adbd 完成 ADB 协议握手（含 RSA 配对，基于 [webadb.js](https://github.com/webadb/webadb.js)），然后下发 `setprop`——等价于浏览器里跑了一遍 adb shell，全程不经过任何服务器。也支持用另一台安卓手机 + OTG 线的 Chrome 打开，手机即电脑。

限制：Chrome/Edge 专用（Firefox/Safari 无 WebUSB）；若电脑上的 adb 程序正占用设备需先退出（或 `adb kill-server`）；连接异常时优先拔插 USB 线，设备端 adbd 偶发挂死时重启阅读器即可恢复。

## 桌面脚本版

### macOS（`eink-mode.command`）

```bash
# 前置: brew install android-platform-tools
./eink-mode.command sharp    # 或 smooth / hd
./eink-mode.command          # 无参数 = 交互选择; 也可直接双击文件
chmod +x eink-mode.command   # 首次使用需加执行权限
```

### Windows（`eink-mode.bat`）

```bat
:: 前置: 安装 Android platform-tools 并加入 PATH
eink-mode.bat sharp    :: 或 smooth / hd
eink-mode.bat          :: 无参数 = 交互选择
```

## AI Agent 直装指引（ADB 命令）

> 本节供 AI 编码代理（Claude Code / Cursor 等）直接执行。设备已 USB 连接并授权调试后，以下命令即完整功能集。

**检查设备：**

```bash
adb devices                      # 应有状态为 device 的条目
adb shell getprop ro.product.model   # 确认型号 (P4)
```

**切换模式（三选一）：**

```bash
# 锐利 (出厂默认)
adb shell "setprop sys.eink.mode 2; setprop sys.eink.dither 1; setprop sys.eink.dither.var_thresh 1000"

# 平滑
adb shell "setprop sys.eink.mode 2; setprop sys.eink.dither 1; setprop sys.eink.dither.var_thresh 100000"

# 超清 (真灰度, 刷新闪屏)
adb shell "setprop sys.eink.mode 4; setprop sys.eink.dither 1; setprop sys.eink.dither.var_thresh 1000"
```

**验证与回读：**

```bash
adb shell "getprop sys.eink.mode; getprop sys.eink.dither; getprop sys.eink.dither.var_thresh"
# 锐利=2/1/1000, 平滑=2/1/100000, 超清=4/1/1000
```

**恢复出厂状态：** 重启设备，或执行锐利档命令。

### AI Agent 调试指引（在线版 WebUSB）

> 在线版页面的调试方法，供 AI 代理复现问题 / 验证修复。实测环境：macOS + Chrome 系浏览器（含 ZCode 内置浏览器，具备 WebUSB）。

**前置纪律（最重要）：**

- 测网页前必须 `adb kill-server`——系统 adb server 会抢占 USB interface（导致 `claimInterface` 失败），且 macOS 上它会被反复拉起，杀掉后的干净窗口通常只有 1–3 分钟，动作要快。
- `requestDevice()` 需要真实用户手势，DOM 派发的 `click()` 无法弹出选择器。自动化测试一律走 `navigator.usb.getDevices()` 已授权设备快路径。
- 首次连接设备屏幕会弹「允许 USB 调试」，需物理点击，自动化只能轮询页面日志等待；可用 `adb shell uiautomator dump` 确认屏幕状态。

**页面缓存坑：** GitHub Pages CDN `max-age=600` 且对带查询参数的 URL 缓存不稳定。调试时导航到**显式路径** `.../EnableTwoBitForEEGOP4/index.html?v=<时间戳>`，并在页面里校验补丁已加载（`Adb.WebUSB.Transport.prototype.send.toString()` 应包含拆包逻辑），不要相信「刷新过了」。

**传输层插桩：** 给页面要用的 USBDevice 实例包记录仪（`getDevices()` 每次返回同一对象，页面 connect 会复用你的包装）：

```js
const d = (await navigator.usb.getDevices()).find(x => x.productName === "P4");
const orig = { out: d.transferOut.bind(d), in: d.transferIn.bind(d) };
d.transferOut = (ep, data) => orig.out(ep, data)
  .then(r => (window.__xfer ??= []).push(`OUT ep${ep} ${data.byteLength}B ${r.status}`), r)
  .catch(e => ((window.__xfer ??= []).push(`OUT ep${ep} ✗`), Promise.reject(e)));
// transferIn 同理；然后点连接，读 window.__xfer
```

**设备端证据（定位根因的关键）：**

```bash
adb shell "logcat -d -s adbd:V" | tail -40
```

两条特征签名：`received packet of unexpected length while reading header` = 合并发包问题（补丁 2）；连续的 `FUNCTIONFS_BIND` / `FUNCTIONFS_ENABLE` = `selectConfiguration` 触发端点重建（补丁 3）。设备端日志 + 主机端插桩对照，比单侧猜测快一个数量级。

**状态污染与恢复：** 一次失败的传输会把 Chrome 侧管道状态毒化，且**页面刷新无效**（USB 句柄活在浏览器进程里）。恢复优先级：`adb kill-server` → 物理拔插 USB → `adb reboot`（本固件 `svc usb setFunctions` 无效）。读卡器端 adbd 挂死后任何电脑都连不上，重启即愈。

## 故障排查

| 现象 | 处理 |
|---|---|
| 在线版连不上 | 电脑 adb 是否正占用设备（`adb kill-server`）；换 Chrome/Edge；重新插拔 USB |
| 在线版报 `transferOut/transferIn: A transfer error` | 先 `adb kill-server`；仍不行就**拔插一次 USB 线**（本页已内置多项兼容补丁，见下方说明） |
| 设备不弹授权框 | 开发者选项里「撤销 USB 调试授权」后重试 |
| 切换后屏幕没变 | 属性是随下一次刷新生效——翻一页或唤醒屏幕 |
| 脚本报 adb 不存在 | macOS: `brew install android-platform-tools`；Windows: 装 platform-tools 并配 PATH |

### 在线版的 webadb.js 兼容补丁（页面已内置，无需操作）

实测 RK3326 方案的 USB 栈与 webadb.js 原版有多处不兼容，页面加载时自动打了补丁：

1. **屏蔽 `USBDevice.reset()`**：webadb.js 每次连接都会调 `USBDevice.reset()`，RK 的 USB gadget 被复位后会直接掉线且无法自恢复（必须物理重插）。
2. **ADB 包拆分发送**：Chrome（尤其 macOS）在一次 `transferOut` 里同时发「24 字节 ADB 头 + 载荷」时，RK 端 adbd 的 FunctionFS 会读到异常长度（设备日志 `received packet of unexpected length while reading header`），连接被立即掐断。补丁把出站包拆成「头部」「载荷」两次传输，与 adbd 的读取节奏对齐。
3. **跳过 `selectConfiguration` / `selectAlternateInterface`**：webadb.js 建连前的这两个标准请求会让 RK3326 的 configfs gadget 当场拆除重建 ADB 端点（adbd 日志可见 FUNCTIONFS_BIND/ENABLE 循环），之后所有传输一律报错。设备插上时本就是已配置状态，这两步纯属多余，补丁跳过只保留 `claimInterface`。

完整分析（含设备端日志证据与可复现实验）：[docs/webadb-compatibility.md](docs/webadb-compatibility.md)。上游 [webadb/webadb.js](https://github.com/webadb/webadb.js) 已归档无法提 issue，此文档即为存档；若未来出现活跃 fork 可直接引用。

## 适用范围

- **实测**：EEGO P4（RK3326 / Android 11 / wetao 固件）
- **理论上适用**：任何使用 `sys.eink.*` 属性体系的同方案墨水屏固件（用 `adb shell getprop | grep eink` 检查你的设备是否有这套属性）
- 配套插件：[BOBDFK](https://github.com/ProLawnMower/BOBDFK) —— KOReader 的 Floyd-Steinberg 抖动插件，与本工具的三种模式深度配合（自动适配 1-bit/2-bit 档位）

## 背景

这三个属性是逆向 EEGO P4 固件（SurfaceFlinger 的 EPD 渲染层）发现的运行时开关：`sys.eink.mode` 控制输出位深（2=1-bit 快刷, 4=2-bit 灰度全刷），`sys.eink.dither.var_thresh` 是文字/图片分流的自适应方差门限（100000 = 文字边缘也走抖动路径）。

## License

MIT（含第三方 [webadb.js](https://github.com/webadb/webadb.js)，其自身为 MIT）

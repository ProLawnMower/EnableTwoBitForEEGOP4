@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM ============================================================
REM  EEGO P4 墨水屏显示模式切换器 (Windows 版)
REM  项目: EnableTwoBitForEEGOP4
REM
REM  用法:
REM    eink-mode.bat [sharp|smooth|hd]    直接切换
REM    eink-mode.bat                      无参数, 交互选择
REM
REM  前置: adb 已安装且在 PATH (https://developer.android.com/tools/releases/platform-tools)
REM        设备 USB 连接并授权调试
REM ============================================================

set "MODE=%~1"

if "%MODE%"=="" goto :menu
if /i "%MODE%"=="sharp"  goto :apply
if /i "%MODE%"=="smooth" goto :apply
if /i "%MODE%"=="hd"     goto :apply
goto :usage

:menu
echo EEGO P4 显示模式切换
echo   1) 锐利 sharp  - 最锐利文字, 快刷不闪 (出厂默认)
echo   2) 平滑 smooth - 文字边缘灰阶平滑, 快刷不闪
echo   3) 超清 hd     - 真 2-bit 灰度, 翻页会闪
set /p choice=选择 [1-3]:
if "%choice%"=="1" set "MODE=sharp"  & goto :apply
if "%choice%"=="2" set "MODE=smooth" & goto :apply
if "%choice%"=="3" set "MODE=hd"     & goto :apply
goto :usage

:apply
set "EINK_MODE=2" & set "VT=1000" & set "LABEL=锐利"
if /i "%MODE%"=="smooth" set "EINK_MODE=2" & set "VT=100000" & set "LABEL=平滑"
if /i "%MODE%"=="hd"     set "EINK_MODE=4" & set "VT=1000"   & set "LABEL=超清"

where adb >nul 2>nul
if errorlevel 1 (
  echo 错误: 未找到 adb, 请安装 Android platform-tools 并加入 PATH
  goto :fail
)

adb shell setprop sys.eink.mode %EINK_MODE%
if errorlevel 1 goto :fail
adb shell setprop sys.eink.dither 1
if errorlevel 1 goto :fail
adb shell setprop sys.eink.dither.var_thresh %VT%
if errorlevel 1 goto :fail

echo.
echo OK: 已切换到 %LABEL% 模式 (mode=%EINK_MODE%, dither=1, var_thresh=%VT%)
timeout /t 3 >nul
exit /b 0

:usage
echo 用法: %0 [sharp^|smooth^|hd]
echo   sharp  = 锐利 (出厂默认, 1-bit 硬阈值文字, 快刷)
echo   smooth = 平滑 (1-bit + 文字边缘抖动灰阶, 快刷)
echo   hd     = 超清 (2-bit 真灰度, 全刷闪屏)
pause
exit /b 1

:fail
echo 失败: 请检查 USB 连接与调试授权
pause
exit /b 1

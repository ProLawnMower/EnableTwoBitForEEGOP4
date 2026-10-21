#!/bin/zsh
# ============================================================
#  EEGO P4 墨水屏显示模式切换器 (macOS 版)
#  项目: EnableTwoBitForEEGOP4
#
#  用法:
#    ./eink-mode.command [sharp|smooth|hd]   # 命令行直接切换
#    ./eink-mode.command                     # 无参数, 交互选择
#    双击文件 = 无参数交互模式
#
#  三种模式:
#    sharp  锐利: 文字纯黑白最锐利, 快刷不闪, 图片系统网点 (出厂默认)
#    smooth 平滑: 文字边缘网点灰阶, 快刷不闪
#    hd     超清: 真 2-bit 四级灰度, 文字图片真灰阶, 但翻页全屏闪
#
#  前置: adb 已安装 (brew install android-platform-tools),
#        设备 USB 连接并授权调试
# ============================================================

MODE="${1:-}"
VALID=(sharp smooth hd)

usage() {
  echo "用法: $0 [sharp|smooth|hd]"
  echo "  sharp  = 锐利 (出厂默认, 1-bit 硬阈值文字, 快刷)"
  echo "  smooth = 平滑 (1-bit + 文字边缘抖动灰阶, 快刷)"
  echo "  hd     = 超清 (2-bit 真灰度, 全刷闪屏)"
  exit 1
}

# 交互选择
if [ -z "$MODE" ]; then
  echo "EEGO P4 显示模式切换"
  echo "  1) 锐利 sharp  - 最锐利文字, 快刷不闪 (出厂)"
  echo "  2) 平滑 smooth - 文字边缘灰阶平滑, 快刷不闪"
  echo "  3) 超清 hd     - 真 2-bit 灰度, 翻页会闪"
  printf "选择 [1-3]: "
  read choice
  case "$choice" in
    1) MODE=sharp ;;
    2) MODE=smooth ;;
    3) MODE=hd ;;
    *) usage ;;
  esac
fi

case "$MODE" in
  sharp)  EINK_MODE=2; DITHER=1; VT=1000;   LABEL="锐利" ;;
  smooth) EINK_MODE=2; DITHER=1; VT=100000; LABEL="平滑" ;;
  hd)     EINK_MODE=4; DITHER=1; VT=1000;   LABEL="超清" ;;
  *) usage ;;
esac

if ! command -v adb >/dev/null 2>&1; then
  echo "错误: 未找到 adb, 请先: brew install android-platform-tools"
  osascript -e 'display notification "未找到 adb" with title "P4 显示模式"' 2>/dev/null
  exit 1
fi

# 等待设备(USB 偶发瞬断自动重试), 最多 15 秒
i=0
while [ $i -lt 5 ] && [ -z "$(adb devices 2>/dev/null | grep -w device)" ]; do
  sleep 3; i=$((i+1))
done

adb shell setprop sys.eink.mode "$EINK_MODE" &&
adb shell setprop sys.eink.dither "$DITHER" &&
adb shell setprop sys.eink.dither.var_thresh "$VT"

if [ $? -eq 0 ]; then
  echo "OK: 已切换到 ${LABEL} 模式 (mode=$EINK_MODE, dither=$DITHER, var_thresh=$VT)"
  osascript -e "display notification \"已切换: ${LABEL}\" with title \"P4 显示模式\"" 2>/dev/null
else
  echo "失败: 请检查 USB 连接与调试授权"
  osascript -e 'display notification "设置失败, 请检查 USB 连接" with title "P4 显示模式"' 2>/dev/null
  exit 1
fi

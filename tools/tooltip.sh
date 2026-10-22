#!/bin/bash
# tooltip.sh X Y [悬停秒数] —— 把鼠标悬停到某点，等提示浮出，截图 OCR 出 tooltip 文本
# 用途：发现 Logic Pro（或任意 App）按钮的名称 + 快捷键
x=${1:?用法: tooltip.sh X Y [秒]}; y=${2:?}; w=${3:-2.2}
export PATH="$HOME/.local/bin:$PATH"
cliclick m:"$x,$y" >/dev/null
sleep "$w"
screencapture -x -R$((x-30)),$((y-18)),340,96 /tmp/_tip.png
sips -z 288 1020 /tmp/_tip.png --out /tmp/_tip_u.png >/dev/null 2>&1
ocr /tmp/_tip_u.png --lang zh-Hans,en-US 2>/dev/null | tr '\n' ' '
echo

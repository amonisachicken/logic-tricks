# 找到 Logic 的界面元素（并抄下它的快捷键）

> 目标：在完全不靠"猜坐标"的前提下，定位 Logic Pro 的按钮/菜单/轨道行，
> 并顺手拿到它的**键盘快捷键**，之后的操作用键盘完成。
>
> 适用：Logic Pro 11.x（Intel/Apple Silicon 皆可）、macOS 13+
> 前置：Terminal 已获「辅助功能」+「屏幕录制」权限，已装 `cliclick`

---

## 0. 为什么先做这一步

坐标点击有三个致命问题：

1. 窗口一动、缩放一变，之前算好的坐标全废；
2. 多点几下就容易点错（我自己就因为点偏，把 Logic 的工程设置窗点开、又误触过静音）；
3. 无法确认“我刚才点的到底是什么”。

而 **tooltip / 菜单 / 键盘** 三种方式都能带**语义**：你知道自己在操作什么。
所以流程固定为：

```
① 悬停读 tooltip（拿名称 + 单字母快捷键）
② 菜单里读 AXMenuItemCmdChar（拿带修饰键的组合快捷键）
③ 截屏 + OCR / 像素扫描（拿坐标，作为最后手段）
④ 每次操作后立刻验证（LCD 读数 / 电平表 / 撤销项名称）
```

---

## 1. 方法 A：悬停读 tooltip（最快，先做这个）

Logic 的按钮悬停约 **1.5–2.5 秒**后弹出提示，内容是 **「名称 + 空格 + 快捷键字母」**。

### 工具

`tools/tooltip.sh`：把鼠标移到某点 → 等提示浮出 → 截鼠标右下区域 → 放大 3× → OCR。

```bash
chmod +x tools/tooltip.sh
./tools/tooltip.sh X Y [悬停秒数]      # 默认 2.2 秒
```

### 实测结果（Logic Pro 11.0.1 / macOS 13）

| 按钮 | tooltip 原文 | 快捷键 |
|---|---|---|
| 全局轨道区右上角的开关 | `显示/隐藏全局轨道 G` | **G** |
| 传输栏录音钮 | `录音 R` | **R** |
| 传输栏循环钮 | `循环 C` | **C** |
| 播放 / 停止 | `播放…` / `停止…` | **空格 / 回车** |
| 工具栏右端 | `编辑器` / `列表编辑器` | E / … |

```bash
$ ./tools/tooltip.sh 962 178
显示/隐藏全局轨道 G
```

### 扫盲式用法（**不需要事先知道按钮在哪**）

沿一行按钮的 y 坐标横扫多个 x —— tooltip 会自己报出"我是谁"：

```bash
for x in 990 1015 1040 1065 1090 1115; do
  echo -n "$x → "; ./tools/tooltip.sh $x 77 1.8
done
# 990 → 倒回
# 1015 → 跳到左定位符
# 1040 → 播放
# 1090 → 录音 R
# 1115 → 自由速度录音
```

### 验证 tooltip 里的快捷键真的有效

拿到 `G` 后，用截图像素一致性验证它确实是那个开关：

```bash
screencapture -x before.png
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "g"'; sleep 1
screencapture -x mid.png
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "g"'; sleep 1
screencapture -x after.png
md5 -q before.png after.png     # 两个值必须一致 → 干净的双向开关
```

### 技巧与坑

- 悬停 **太短拿不到文字**（只有高亮），至少 1.5 s。
- tooltip 画在鼠标附近，通常右下 30–60 px；截图区取 `x-30, y-18, 340×96` 最稳。
- OCR 会把字母和中文粘连成 `循环C`、`录音 R`，**取末尾单个 A–Z 字母**当快捷键。
- 抓完立刻把鼠标移开（`cliclick m:1200,700`），否则 tooltip 污染下一次截图。
- tooltip **只给单字母**快捷键；`⌘T`、`⌘R` 这类带修饰键的要用方法 B。

---

## 2. 方法 B：从菜单里读组合快捷键（AX）

Logic 所有菜单命令都能通过 AppleScript 枚举，**并且能读出快捷键**。

```bash
# 列出一级菜单
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to return name of every menu bar item of menu bar 1'

# 列出某个菜单的所有项
osascript <<'EOF'
tell application "System Events" to tell process "Logic Pro X"
  set out to {}
  repeat with mi in menu items of menu 1 of menu bar item "编辑" of menu bar 1
    if name of mi is not missing value then set end of out to name of mi
  end repeat
  return out
end tell
EOF

# ★ 读某项的快捷键与修饰键（不用猜）
osascript <<'EOF'
tell application "System Events" to tell process "Logic Pro X"
  set mi to menu item "重复" of menu 1 of menu bar item "编辑" of menu bar 1
  return {name of mi, ¬
          value of attribute "AXMenuItemCmdChar" of mi, ¬
          value of attribute "AXMenuItemCmdModifiers" of mi}
end tell
EOF
```

`AXMenuItemCmdModifiers` 的位义：

| 值 | 含义 |
|---|---|
| 0 | ⌘ |
| 1 | ⇧ |
| 2 | ⌥ |
| 4 | ⌃ |
| 8 | 无修饰键（菜单项没有快捷键时的默认值） |

### 子菜单（含实战值）

```bash
osascript <<'EOF'
tell application "System Events" to tell process "Logic Pro X"
  set j to menu item "并轨和接合" of menu 1 of menu bar item "编辑" of menu bar 1
  set out to {}
  repeat with s in menu items of menu 1 of j
    if name of s is not missing value then
      set end of out to (name of s) & " [key:" & (value of attribute "AXMenuItemCmdChar" of s) & "]"
    end if
  end repeat
  return out
end tell
EOF
# → 原位并轨片段… [key:], 接合 [key:J], 按轨道接合 [key:J]
```

### 实测拿到的关键快捷键

| 动作 | 菜单路径 | 快捷键 |
|---|---|---|
| 在播放头处拆分片段 | 编辑 › 拆分 › 播放头处的片段 | **⌘T** |
| 在定位符处拆分 | 编辑 › 拆分 › 定位符处的片段 | **⌃T** |
| 重复（一次） | 编辑 › 重复 › **一次** | **⌘R** |
| 重复（多次…） | 编辑 › 重复 › 多次… | 无（子菜单） |
| 接合 | 编辑 › 并轨和接合 › 接合 | **⌘J** |
| 选择全部 | 编辑 › 选择 › 全部 | ⌘A |

⚠️ **注意**：顶层「重复」项**没有** `AXMenuItemCmdChar`（因为它是个子菜单），
快捷键挂在子项「一次」上。遇到 `missing value` 就先展开子菜单看子项。

### AX 的硬限制：三级嵌套菜单读不到

```applescript
-- ❌ 报 -1719 无效的索引
menu 1 of menu item "显示单个全局轨道" of menu 1 of menu item "全局轨道" of menu 1 of menu bar item "轨道"
```

`轨道 › 全局轨道 › 显示单个全局轨道 › …` 是**三级**嵌套，AppleScript 只能展开到第二级。
这类只能用鼠标逐级悬停点开，或者干脆改用该功能的单键快捷键。

### 另一类坑：子菜单项名字带时间戳

`文件 › 复原到` 的项名字是：

```
已存储\t\t2026/10/22 23:49:17
备份 1\t\t2026/10/22 23:42:29
```

所以 `click menu item "已存储"` 会报 **-1728**。必须**前缀匹配**：

```applescript
set rv to menu 1 of menu item "复原到" of menu 1 of menu bar item "文件" of menu bar 1
repeat with s in (menu items of rv)
  if (name of s as string) starts with "已存储" then click s
end repeat
```

并且**要先点开父菜单**再取子菜单，否则时好时坏（菜单还没构建）：

```applescript
click menu bar item "文件" of menu bar 1
delay 0.6
click menu item "复原到" of menu 1 of menu bar item "文件" of menu bar 1
delay 0.6
-- 这时才能拿到 menu 1 of menu item "复原到"
```

---

## 3. 方法 C：截图 + OCR（要坐标时用）

### 截图

```bash
screencapture -x /tmp/s.png                     # 全屏，-x 静音
screencapture -x -R700,150,760,200 /tmp/r.png   # 区域 x,y,w,h（物理像素）
screencapture -x -l <windowid> /tmp/w.png       # 指定窗口
```

**只截当前 Space**：窗口在别的桌面/全屏空间时截不到。

### OCR（Vision 框架，中文极准，0.25 s）

```bash
swiftc -O -o tools/ocr tools/ocr.swift
./tools/ocr /tmp/s.png                 # 纯文本（默认 zh-Hans + en-US）
./tools/ocr /tmp/s.png --boxes         # 每行附带归一化坐标
./tools/ocr /tmp/s.png --json          # 结构化输出
sips -z 400 1520 /tmp/s.png --out /tmp/s_up.png   # 先放大 2–4 倍，小字命中率明显提高
```

归一化坐标 → 屏幕像素（Vision 原点在**左下**，屏幕在**左上**）：

```
px = crop_x0 + x * crop_w
py = crop_y0 + (1 - y - h) * crop_h
```

`tools/probe.py` 把"截图 + OCR + 坐标换算"合成一步，直接输出 `文字 → 屏幕 x`。

### 实例：读 Logic 的播放头位置（最重要的验证手段）

```bash
screencapture -x -R1185,55,180,40 /tmp/lcd.png
sips -z 90 405 /tmp/lcd.png --out /tmp/lcd_u.png
./tools/ocr /tmp/lcd_u.png --lang en-US
# → 009 1 1 001   （小节 9 | 拍 1 | 等份 1 | 音位 001）
```

**每一步都读 LCD 是保证不跑偏的关键**（点标尺定位后必读）。

---

## 4. 方法 D：像素扫描找边界（OCR 不够精确时）

`tools/scan.swift` 扫描某一行像素的颜色突变点，**精确到 1 px**：

```bash
swiftc -O -o tools/scan tools/scan.swift
./tools/scan /tmp/crop.png 15
# → 0(209,209,209) 39(174,174,174) 40(250,250,250) 87(88,88,88) ...
```

实战用途：

1. **判断两个元素是否对齐**（例如和弦段边界是否等于片段边界）：
   ```bash
   screencapture -x -R1330,372,120,26 /tmp/a.png   # 和弦行
   screencapture -x -R1330,412,120,30 /tmp/b.png   # 片段行
   ./tools/scan /tmp/a.png 12   # 突变点 x 一致 → 同一条小节线
   ./tools/scan /tmp/b.png 15
   ```
2. **量出某行里的分段边界**（轨道头按钮、面板分隔线）。
3. **验证状态**（例：静音按钮底色 `(31,122,153)` = 蓝色 = 已静音）。

---

## 5. 定位 Logic 自身的结构（不靠猜）

| 想知道 | 命令 |
|---|---|
| 窗口位置/尺寸 | `osascript -e 'tell application "System Events" to tell process "Logic Pro X" to return {position of window 1, size of window 1}'` |
| 窗口标题（就是工程名） | `… to return name of window 1` |
| 前台是不是 Logic | `… to return name of first process whose frontmost is true` |
| 当前工具/焦点 | 截工具栏那一行，`scan` 看哪个按钮是蓝色高亮 |
| 小节线的 x | 截图标尺 → OCR 出 `1/3/5/7/9…` → 线性拟合 `每小节 ≈ 48 px`（本例） |

> 逻辑类推：**只要能从截图上读到两个已知刻度，任何网格坐标都能算出来**，
> 再用 `scan` 校准一次即可。但能不用坐标就别用。

---

## 6. 找到元素之后：怎么"点"才安全

优先级从高到低：

| 手段 | 稳定性 | 备注 |
|---|---|---|
| 菜单项点击（AX） | ★★★★★ | 不受窗口位置影响 |
| 单字母/组合快捷键 | ★★★★★ | 用定向 `tell process "Logic Pro X" to keystroke` |
| 控件名点击 | ★★★★ | Logic 自绘 UI 多半拿不到控件树 |
| 坐标点击（cliclick） | ★★ | 窗口一动就错，且物理点击会落到别的 App |

定向键盘（安全）：

```bash
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "r"'
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "t" using command down'
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to key code 53'   # Esc
```

**`tell process "X" to keystroke` 是定向投递的**：即使别的 App 在前台也会送到 Logic。
反过来，`cliclick` 是物理点击，落在当时最前面的窗口上 —— 机器有人在用时极其危险。

---

## 7. 验证清单（每步都要做）

| 想验证 | 手段 |
|---|---|
| 位置/小节 | 读 LCD（`009 1 1 001`） |
| 有没有出声 | 轨道头**电平表**（绿色条+黄色峰值） |
| 上一步是什么操作 | 读 `编辑` 菜单首项（`撤销拆分片段` / `撤销MIDI 录音` / `撤销量化`） |
| 数量 | Logic 自己的读数（`片段：N 个已选择`、`N 个音符`） |
| 边界是否对齐 | `scan` 比较突变点 |
| 开关是否切换 | 前后截图 `md5` 一致（两次切换回到原状） |

---

## 8. 一分钟速查

```bash
# 工具编译
for f in ocr scan; do swiftc -O -o tools/$f tools/$f.swift; done
chmod +x tools/tooltip.sh

# 悬停抄快捷键
./tools/tooltip.sh 962 178          # → 显示/隐藏全局轨道 G

# 盲扫一排按钮
for x in 990 1015 1040 1065 1090; do ./tools/tooltip.sh $x 77 1.8; done

# 读菜单快捷键
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to return {value of attribute "AXMenuItemCmdChar" of menu item "播放头处的片段" of menu 1 of menu item "拆分" of menu 1 of menu bar item "编辑" of menu bar 1}'

# 看当前播放头
screencapture -x -R1185,55,180,40 /tmp/l.png && sips -z 90 405 /tmp/l.png --out /tmp/l_u.png && ./tools/ocr /tmp/l_u.png --lang en-US
```

---

## 9. 已知限制

- Logic 的编排区/和弦轨是**自绘 UI**，AX 里没有控件树，只能靠快捷键/菜单/OCR。
- `⌘D` 在轨道头被选中时是"创建轨道"，不是"重复片段"；`⌥↓` 是"移调"不是滚动。
  **任何快捷键都要先从菜单/tooltip 确认语义再用。**
- 三级嵌套菜单 AX 读不到（见 §2）。
- 截图只含当前 Space。
- 密码框、TCC 授权弹窗、登录界面无法代操作。

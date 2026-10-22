# logic-tricks

用**脚本 + 命令行**操作 Logic Pro 的实战技能集：找界面元素、建和弦轨、灌 MIDI 并录音。
每一招都在 Logic Pro 11.0.1 / macOS 13.7.2（Intel iMac）上**实测通过**，包含踩过的坑与验证方法。

> 面向：想让 AI 代理（或自己的脚本）驱动 Logic，而不想靠"盲点坐标"的人。

---

## 它解决什么问题

Logic 的编排区、和弦轨都是**自绘 UI**，辅助功能（AX）里几乎没有控件树，常见做法是硬编码屏幕坐标 —— 窗口一动就全废。
本仓库整理的路线是：

```
tooltip 抄快捷键  →  菜单 AX 查组合键  →  键盘操作  →  （最后才）坐标点击
```

每一步都配了**客观验证手段**（LCD 读数、电平表、撤销项名称、像素扫描），保证"操作真的生效了"。

---

## 目录

```
logic-tricks/
├── README.md
├── docs/
│   ├── 01-find-ui-elements.md   # 找到界面元素 + 抄快捷键（含 tooltip 盲扫法）
│   ├── 02-chord-track.md        # 在 Logic 11 和弦轨里建和弦进行
│   └── 03-midi-record.md        # 注入 MIDI / 音乐键入，并录成真正的 MIDI 片段
└── tools/
    ├── ocr.swift        # Vision 框架 OCR（中英，0.25s，输出坐标）
    ├── scan.swift       # 逐像素扫描，找 UI 分界线（精确到 1px）
    ├── tooltip.sh       # 悬停取 tooltip → 抄按钮快捷键
    ├── probe.py         # 截图 + OCR + 坐标换算一条龙
    ├── pi-midi.swift    # CoreMIDI 虚拟源，把音符直接灌给 Logic
    └── keys.swift       # CGEvent 同时按住多个键（音乐键入弹和弦）
```

---

## 环境要求

| 项 | 要求 |
|---|---|
| 系统 | macOS 13+（Vision OCR / CoreMIDI 需要） |
| Logic | Logic Pro 11.x（和弦轨是 11 才有的功能） |
| 权限 | 系统设置 → 隐私与安全性 → **辅助功能**、**屏幕录制** → 勾选 **Terminal** |
| 依赖 | `cliclick`（`brew install cliclick`）、Xcode Command Line Tools（`swiftc`、`screencapture`、`sips`） |

权限自检：

```bash
osascript -e 'tell application "System Events" to return name of every process whose background only is false'  # 辅助功能
screencapture -x /tmp/t.png && echo 截图OK                                                                   # 屏幕录制
```

---

## 快速开始

```bash
git clone git@github.com:amonisachicken/logic-tricks.git
cd logic-tricks

# 编译工具（～20 秒）
swiftc -O -o tools/ocr      tools/ocr.swift
swiftc -O -o tools/scan     tools/scan.swift
swiftc -O -o tools/pi-midi  tools/pi-midi.swift
swiftc -O -o tools/keys     tools/keys.swift
chmod +x tools/tooltip.sh

# 试试：悬停拿一个快捷捷
./tools/tooltip.sh 962 178
# → 显示/隐藏全局轨道 G
```

---

## 三条技能一览

### 1️⃣ 找界面元素 → [docs/01-find-ui-elements.md](docs/01-find-ui-elements.md)

- **tooltip 抄快捷键**：Logic 按钮悬停 ~2 s 弹出「名称 + 快捷键字母」
- **盲扫法**：沿一行按钮横扫 x，tooltip 自己报"我是谁"，不用事先知道按钮位置
- **菜单 AX**：读 `AXMenuItemCmdChar` / `AXMenuItemCmdModifiers` 反查组合键
- **OCR / 像素扫描**：要坐标时用，精度到 1 px
- 四级优先级：菜单 > 快捷键 > 控件名 > 坐标

```bash
./tools/tooltip.sh 962 178                    # 显示/隐藏全局轨道 G
for x in 990 1015 1040 1065 1090; do ./tools/tooltip.sh $x 77 1.8; done   # 盲扫传输栏
```

### 2️⃣ 建和弦轨 → [docs/02-chord-track.md](docs/02-chord-track.md)

- 和弦行两个入口：行首「和弦 ⌄」下拉、行尾 **⊕**（在播放头创建）
- 逐小节「点标尺定位 → 读 LCD → 点 ⊕」是**最稳**的建法（不需要 `⌘T`）
- 改名：双击和弦段 → 和弦编辑器浮窗 → `⌘A` → 输入 → `Return` → `Esc`
- 和弦写法：`Bb` / `Ab`（**降号后置**）有效，`bB` / `bA` 会被误解析

```bash
cliclick c:1031,170     # 定位到第 2 小节（记得读 LCD 确认）
cliclick c:963,378      # 点 ⊕ 在该小节建和弦
```

### 3️⃣ MIDI 注入 + 录音 → [docs/03-midi-record.md](docs/03-midi-record.md)

- **A. CoreMIDI 虚拟源**（`pi-midi`）：音高/力度/时值全可控
- **B. ⌘K 音乐键入 + CGEvent**（`keys`）：真按键，可同时按住多个键弹和弦
- 录音：预备拍 1 小节 + 延迟补偿 + `R` 开始/空格停止 + 量化到小节
- 验证：轨道头**电平表** + 卷帘的 `N 个音符` 读数

```bash
./tools/pi-midi chords 2.0              # 每小节 2.0 s（120BPM = 1 小节）
./tools/keys 0,2,5 1.2                  # 音乐键入弹 C 大三和弦
```

---

## 常用脚本配方

```bash
LOGIC='tell application "System Events" to tell process "Logic Pro X"'

# 定向键盘（即使别的 App 在前台也会送到 Logic）
osascript -e "$LOGIC to keystroke \"r\""                        # 录音
osascript -e "$LOGIC to keystroke \"t\" using command down"      # 在播放头拆分
osascript -e "$LOGIC to keystroke \"g\""                        # 显示/隐藏全局轨道
osascript -e "$LOGIC to key code 53"                            # Esc

# 读播放头位置（最重要的验证手段）
screencapture -x -R1185,55,180,40 /tmp/l.png
sips -z 90 405 /tmp/l.png --out /tmp/l_u.png
./tools/ocr /tmp/l_u.png --lang en-US          # → 009 1 1 001

# 读上一步做了什么（撤销项名称）
osascript -e "$LOGIC to return name of menu item 1 of menu 1 of menu bar item \"编辑\" of menu bar 1"

# 比较两个 UI 行是否对齐
./tools/scan /tmp/a.png 12 && ./tools/scan /tmp/b.png 15
```

---

## 已验证的 Logic 快捷键

| 动作 | 键 | 来源 |
|---|---|---|
| 显示/隐藏全局轨道 | `G` | tooltip |
| 录音 | `R` | tooltip |
| 循环 | `C` | tooltip |
| 音乐键入 | `⌘K` | 菜单 |
| 在播放头处拆分 | `⌘T` | 菜单 AX |
| 重复（一次） | `⌘R` | 菜单 AX（子项） |
| 接合 | `⌘J` | 菜单 AX |
| 全选 | `⌘A` | 菜单 |

⚠️ **语义陷阱**（都实测过）：

- `⌘D` 在轨道头被选中时是**创建轨道**，不是"重复片段"
- `⌥↓` 是**移调**，不是"向下滚动"
- `⌘T` 拆的是**有焦点的那一层**：焦点在片段区就会把 MIDI 片段切碎（伴奏乐手/鼓手片段无法 `⌘J` 拼回）

---

## 安全约定

1. **动手前备份工程**（`File › 存储为…` 或复制 `.logicx` 包）；
2. **每个快捷键都先从菜单/tooltip 确认语义**，不要靠肌肉记忆；
3. **每一步之后都验证**（截图 / LCD / 撤销项名称）；
4. 出问题先看 `编辑` 菜单首项的"撤销 XXX"名字，确认撤销的是哪一步；
5. 有人同时在用这台机器时，**不要用 cliclick 坐标点击**（物理点击会落到最前面的窗口），
   用 `tell process "Logic Pro X" to keystroke` 定向投递。

出事了怎么回滚：

```
文件 › 复原到 › 已存储     # 注意：项名带时间戳，且确认框延迟 2–3 秒才弹出
```

---

## 实测环境

| 项 | 值 |
|---|---|
| 机器 | iMac20,2 / i9-10910 / 64 GB / macOS 13.7.2 |
| Logic | Logic Pro 11.0.1 (6029) |
| 工程 | `the train verse.logicx`（120 BPM, 4/4, C 大调） |
| 界面语言 | 简体中文 |

> 换语言版本时，菜单名要对应替换，**快捷键不变**。

---

## License

MIT

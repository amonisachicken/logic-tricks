# 用脚本"弹"MIDI 并录进 Logic 轨道

> 目标：不碰真实键盘，用命令行把音符灌进 Logic 的软件乐器轨道，并**录成真正的 MIDI 片段**。
>
> 两种注入方式都已实测：
> **A. CoreMIDI 虚拟源**（精确控制音高/力度/时值）
> **B. ⌘K 音乐键入 + CGEvent 按键**（模拟按键）
>
> 适用：Logic Pro 11.0.1、macOS 13+（Intel / Apple Silicon 均可）

---

## 0. 前置：让音轨"能响"

声音能不能出来，取决于三件事，缺一不响：

| 条件 | 说明 |
|---|---|
| 目标轨是**软件乐器轨**且有音色 | 例如 `经典电钢琴`（E-Piano） |
| **R（录音使能）** 点亮 | 轨道头的红色 R |
| **I（输入监听）** 点亮 | 轨道头的橙色 I（不录只监听时可以只开这个） |

验证"真的出声了"的客观手段：**轨道头电平表** —— 播放时出现绿色条 + 黄色峰值。
（不要靠耳朵或窗口高亮判断，脚本里没法听。）

---

## 1. 方式 A：CoreMIDI 虚拟源（推荐）

`tools/pi-midi.swift` 建一个名为 `pi-keys` 的虚拟 MIDI 源，Logic 会把它当成一个普通 MIDI 输入设备。

```bash
swiftc -O -o tools/pi-midi tools/pi-midi.swift

./tools/pi-midi list                    # 列出 MIDI 源（能看到 pi-keys 和你的硬件键盘）
./tools/pi-midi note C4 100 1.0         # 单音：音名 力度 时长(秒)
./tools/pi-midi raw 144,60,100          # 原始字节（144=0x90 note-on）
./tools/pi-midi chords                  # 内置 8 小节和弦进行（默认每小节 1.5 s）
./tools/pi-midi chords 2.0              # 每小节 2.0 s（120 BPM 下 = 1 小节）
./tools/pi-midi chords 2.0 1.85         # 再追加：等 1.85 s 再开始（录音等预备拍用）
```

### 原理（三行核心代码）

```swift
MIDIClientCreateWithBlock("pi-client" as CFString, &client, nil)
MIDISourceCreate(client, "pi-keys" as CFString, &source)      // 建虚拟源
var p = MIDIPacketListInit(&list); p = MIDIPacketListAdd(&list, sz, p, 0, n, bytes)
MIDIReceived(source, &list)                                    // 发出去
```

### 内置和弦进行

```swift
("C",     36, [60,64,67]),      // C2  + C4 E4 G4
("Em/B",  35, [64,67,71]),      // B1  + E4 G4 B4
("C7/Bb", 34, [60,64,67,70]),   // Bb1 + C4 E4 G4 Bb4
("F/A",   33, [65,69,72]),      // A1  + F4 A4 C5
("Fm/Ab", 32, [65,68,72]),      // Ab1 + F4 Ab4 C5
("C/G",   31, [60,64,67]),      // G1  + C4 E4 G4
("D/Gb",  30, [62,66,69]),      // Gb1 + D4 F#4 A4
("G",     31, [62,67,71]),      // G1  + D4 G4 B4
```

（第一个数字是低音 MIDI 号，后面是和弦音）

> `pi-keys` 虚拟源**随进程退出而消失**，必须"边跑边听"。

---

## 2. 方式 B：⌘K 音乐键入 + CGEvent 按住多键

```bash
# 1) 打开音乐键入浮窗
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "k" using command down'
# 2) 需要更清亮的音区时，用 X 把「八度音程」从 C2 升到 C4（Z 降 / X 升）
# 3) 弹和弦：同时按住 A + D + G = C 大三和弦
swiftc -O -o tools/keys tools/keys.swift
./tools/keys 0,2,5 1.2      # keycode 列表 + 按住秒数
```

音乐键入键位（Logic 默认映射 + macOS keycode）：

| 键 | 音 | keycode | 键 | 音 | keycode |
|---|---|---|---|---|---|
| A | C | 0 | W | C♯ | 13 |
| S | D | 1 | E | E♭ | 14 |
| D | E | 2 | T | F♯ | 17 |
| F | F | 3 | Y | A♭ | 16 |
| G | G | 5 | U | B♭ | 32 |
| H | A | 4 | O | C♯+1 | 31 |
| J | B | 38 | P | E♭+1 | 35 |
| K | C+1 | 40 | ; | E+1 | 41 |
| L | D+1 | 37 | | | |

`Z / X` 降/升八度，`C / V` 调力度，`tab` 延音。

### ⚠️ 关键坑：AppleScript 的 `key down` 对普通字母不可靠

```applescript
-- ❌ 不报错，但也不产生持续按键 → 弹不出和弦
tell application "System Events" to tell process "Logic Pro X"
  key down "a"
  delay 2
  key up "a"
end tell
```

必须用 **CGEvent** 注入真正的 keyDown/keyUp（`tools/keys` 就是这么做的，并且可以同时按住多个键）。
另外音乐键入浮窗**截不到按键高亮**，别用高亮判断有没有弹响，看电平表。

---

## 3. 录进轨道（预备拍 + 量化）

### 3.1 确认预备拍

`文件 › 项目设置 › 录音…` → 开始: **☑ 预备拍 [1 小节]**

4/4 拍下 1 小节 = **4 拍**；120 BPM 时 = **2.0 秒**。

### 3.2 录音时序（延时补偿）

```bash
# 0) 目标轨 R + I 点亮；播放头到第 1 小节（读 LCD 确认 001 1 1 001）
# 1) 先启动 MIDI（内部延迟等预备拍），紧接着按 R 开始录音
( ./tools/pi-midi chords 2.0 1.85 > /tmp/rec.log 2>&1 & )
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "r"'
sleep 19                                                                # 2s 预备拍 + 16s 演奏 + 富余
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke " "'   # 空格停止
# 2) 校验
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to return name of menu item 1 of menu 1 of menu bar item "编辑" of menu bar 1'
# → 撤销MIDI 录音
```

**为什么是 1.85 s**：`pi-midi` 建虚拟端口约 0.3 s；osascript 触发 `R` 约 0.1–0.2 s。
要让"第一个音"落在预备拍结束、录音真正开始的瞬间，需要手工补偿：

```
0.3(建端口) + 1.85(延迟) ≈ 0.15(按R耗时) + 2.0(预备拍)
```

实测仍有 ~0.3 拍偏差 → 所以下一步要量化。

### 3.3 量化到小节线

1. 选中录到的 MIDI 片段 → 下方面板切到 **钢琴卷帘**；
2. 卷帘内 `⌘A` 全选音符；
3. 左侧「**时间量化**」下拉 → 选 **全音符**（4/4 下 = 1 小节）→ 点旁边的 **量化** 按钮；
4. 校验：编辑菜单首项变为 `撤销量化`，音符起点全部贴齐小节线；
5. **把「时间量化」改回 `16 分音符`**（否则以后编辑都被吸到小节）。

### 3.4 结果核对

钢琴卷帘左上角会显示：

```
33 个音符（C6,7,maj7,9,11,#11,b13）在 经典电钢琴 中
```

本例 33 = 8 个和弦 ×(1 低音 + 3~4 和弦音)，可直接用来核对有没有漏音。

---

## 4. 完整可复现脚本

```bash
#!/bin/bash
# record-chords.sh —— 把 8 小节和弦进行录进当前 R 使能的软件乐器轨
set -e
LOGIC='tell application "System Events" to tell process "Logic Pro X"'

# 1) 播放头到第 1 小节
osascript -e "$LOGIC to keystroke \" \" " 2>/dev/null || true
# （用标尺点击或 Return 更稳；这里假设播放头已在第 1 小节）

# 2) 启动 MIDI（延迟 1.85s 等预备拍），同时按 R
( ./tools/pi-midi chords 2.0 1.85 > /tmp/rec.log 2>&1 & )
osascript -e "$LOGIC to keystroke \"r\""
sleep 19
osascript -e "$LOGIC to keystroke \" \""

# 3) 检查
osascript -e "$LOGIC to return name of menu item 1 of menu 1 of menu bar item \"编辑\" of menu bar 1"
screencapture -x /tmp/after-record.png     # 看轨道上是否出现绿色 MIDI 片段
```

---

## 5. 坑位清单（都踩过）

| 坑 | 现象 | 对策 |
|---|---|---|
| R / I 未开 | 完全无声 | 先点 R + I，再看电平表 |
| AppleScript `key down` | 音乐键入弹不出和弦 | 用 CGEvent（`tools/keys`） |
| 虚拟源消失 | 先建源、后录音没声音 | 边跑边录，同一进程内发声 |
| 预备拍时机 | 整段录音整体偏移 ~0.3 拍 | 延迟补偿 + 录完量化到小节 |
| 音乐键入音域 | 弹出来偏低 | `X` 升八度（C2 → C4） |
| 片段尾部空白 | 片段比音符长 1–2 小节 | 拖右边缘修剪，或忽略 |
| 轨道 M 被点亮 | 只有钢琴有声、伴奏没声 | 检查轨道头 M（蓝色=静音） |
| 时间量化残留 | 后续编辑被吸到整小节 | 用完改回 `16 分音符` |
| 录音覆盖旧片段 | 同轨已有内容 | 先备份工程，或录到空轨 |

---

## 6. 速查

```bash
# 编译
swiftc -O -o tools/pi-midi tools/pi-midi.swift
swiftc -O -o tools/keys tools/keys.swift

# 试听（不入库）
./tools/pi-midi list
./tools/pi-midi note C4 100 1.0
./tools/pi-midi chords 1.5

# 音乐键入
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "k" using command down'
./tools/keys 0,2,5 1.2          # C 大三和弦

# 录音
( ./tools/pi-midi chords 2.0 1.85 & )
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "r"'
sleep 19
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke " "'

# 校验
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to return name of menu item 1 of menu 1 of menu bar item "编辑" of menu bar 1'
screencapture -x -R700,195,300,60 /tmp/meter.png    # 电平表：绿色条+黄色峰值 = 有声
```

---

## 7. 扩展想法

- 把 `pi-midi` 的 `chords` 换成从文本/JSON 读谱：`pi-midi play score.json`；
- 用 CoreMIDI **时间戳**（`MIDIPacketListAdd` 的 timestamp 参数）替代 `sleep`，可做到 ±1 ms 级精度；
- 想把"和弦轨的和弦"直接变成 MIDI：Logic 11 支持从和弦轨生成 MIDI 区域，
  再配合本文档的录音流程对比效果；
- 需要听回放效果时，把轨道 M 都打开，并确认主输出没有被静音。

# 在 Logic Pro 11 的和弦轨里建一段和弦进行

> 目标：不碰 MIDI 编辑器，直接在**和弦轨（Chord Track）**里写出 8 小节和弦进行，
> 例如 `C – Em/B – C7/B♭ – F/A – Fm/A♭ – C/G – D/G♭ – G`（一小节一个和弦）。
>
> 适用：Logic Pro 11.0.1（和弦轨是 11 才有的功能）、macOS 13+
> 前置：见 [01-find-ui-elements.md](01-find-ui-elements.md)（会读 LCD、会用 `⊕`/`⌘T`/双击）

---

## 0. 和弦轨长什么样

和弦轨挂在**全局轨道区**里（跟 编配 / 标记 / 速度 / 拍号 是邻居）。

```
按 G 显示/隐藏全局轨道
  ┌────────┬──────────────────────────────────────────┐
  │  和弦 ⌄ │  C  │ Em/B │ C7/B♭ │ F/A │ …            │  ← 这一行
  └────────┴──────────────────────────────────────────┘
      ↑行首下拉                          ↑行尾 ⊕（创建）
```

| 位置 | 单击效果 | 菜单内容 |
|---|---|---|
| 行首 **「和弦 ⌄」下拉** | 弹出菜单 | `创建和弦` / `粘贴` / **`选择所有和弦`** / `选择循环范围内的所有和弦` |
| 行尾 **⊕** | 在**播放头**处创建和弦（并把前一个和弦截断到这里） | — |
| 和弦段**双击** | 弹出「和弦编辑器」浮窗 | 可输入和弦名、选根音/类型/低音/音阶 |

> 用 `G` 可在"只显示单个全局轨道（和弦）"和"显示全部全局轨道"之间切换。
> 判断方法：悬停全局轨道区右上角，tooltip 显示 `显示/隐藏全局轨道 G`。

---

## 1. 建和弦的最稳流程（推荐）

**核心原则：只碰「标尺」和「和弦行」，绝不点轨道区**（原因见 §4）。

```bash
# 前置
export PATH="$HOME/.local/bin:$PATH"      # cliclick / ocr 在这里

# ① 定位播放头：点标尺第 n 小节线，然后读 LCD 确认 = n|1|1|1
cliclick c:983,170            # 第 1 小节的 x（需按当前窗口重新测量，见下）
screencapture -x -R1185,55,180,40 /tmp/lcd.png
sips -z 90 405 /tmp/lcd.png --out /tmp/lcd_u.png
./tools/ocr /tmp/lcd_u.png --lang en-US    # 期望 001 1 1 001

# ② 点行尾 ⊕ 创建和弦（播放头在第 n 小节 → 就在第 n 小节建一个）
cliclick c:963,378

# ③ n = 1..8 重复 ①②，得到 8 个一小节的和弦
```

### 坐标怎么来（每次窗口变化都要重测）

1. 截标尺一条横条 → OCR 出 `1 / 3 / 7 / 9 / 13 …` 的 x；
2. 线性拟合出 `每小节像素宽 ≈ 48 px`、`bar1_x`；
3. 第 n 小节 x = `bar1_x + (n-1)*每小节宽`；
4. 标尺的**可点击带**在数字下方（本例 y ≈ 170；点数字那一行常常点不动）。

> 实测：`bar1 ≈ 983`、每小节 `≈ 48 px`、标尺点击 `y = 170`、和弦行 `y = 378`、
> 行尾 ⊕ 在 `x ≈ 963`。窗口位置/缩放一变，全部要重算 —— 所以更推荐用 `G` + 菜单/快捷键。

---

## 2. 改和弦名（双击进入和弦编辑器）

```
双击该小节的和弦段 → 浮窗「和弦编辑器」→ ⌘A 全选 → 输入和弦名 → Return 生效 → Esc 关闭
```

浮窗里除了和弦名，还有：**根音符 / Maj·Min·Sus2·Sus4·5·Aug·6·7·maj7·b9·9… / 低音符 / 音阶 / MIDI 输入·试听**。

> ⚠️ 浮窗会**盖住左侧 4~5 个小节**。批量改名时，每改完一个必须 `Esc` 关掉，
> 否则下一次双击会打浮窗上。

### 和弦写法（实测，很重要）

| 想要 | 输入 | 结果 |
|---|---|---|
| B♭（降号后置） | `C7/Bb` | ✅ `C7/B♭` |
| A♭ | `Fm/Ab` | ✅ `Fm/A♭` |
| **降号前置** ❌ | `C7/bB`、`Fm/bA`、`D/bG` | ❌ 被误解析（实测变成 `Fm/B`、`Bm7`） |
| G♭ 作低音 | `D/Gb` | ⚠️ 显示为 `D/F♯`（等音异名，按调性自动拼写） |

**结论：降号一律后置写 `Bb` / `Ab`，不要写 `bB` / `bA`。**

---

## 3. 用 `⌘T` 拆分和弦段（可行，但有风险）

`⌘T` = 编辑 › 拆分 › **播放头处的片段**。它对**和弦轨**和**片段区**都生效，
**看谁有焦点**。

```bash
# 正确姿势：先让和弦轨拿到焦点
cliclick c:1100,378                                # 单击任一个和弦段
cliclick c:<第 n 小节的 x>,170                      # 点标尺定位（读 LCD 确认）
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "t" using command down'
```

拆分后撤销项会显示 `撤销拆分片段`。

> 但**建和弦根本不需要 `⌘T`**：逐小节「定位 + ⊕」更稳，因为没有焦点歧义。

---

## 4. 最大的坑：`⌘T` 会切碎 MIDI 片段

如果点完标尺后焦点落在**片段区**（很常见），`⌘T` 切的是伴奏乐手/鼓手片段：

- 片段被切成 2/3/4/8/9 小节边界上的小块；
- **伴奏乐手（Session Player）/ 鼓手片段无法 `⌘J` 接合**，拼不回去；
- 只能靠 `文件 › 复原到 › 已存储` 回滚。

### 救援：复原到已存储

```applescript
tell application "System Events" to tell process "Logic Pro X"
  click menu bar item "文件" of menu bar 1          -- 必须先点开父菜单
  delay 0.6
  set fm to menu 1 of menu bar item "文件" of menu bar 1
  click menu item "复原到" of fm
  delay 0.6
  set rv to menu 1 of menu item "复原到" of fm
  repeat with s in (menu items of rv)                -- 项名带时间戳，必须前缀匹配
    if (name of s as string) starts with "已存储" then click s
  end repeat
end tell
```

- 项名形如 `已存储\t\t2026/10/22 23:49:17`，用 `click menu item "已存储"` 会报 **-1728**。
- 随后的确认框**延迟约 2–3 秒**才弹出，且 AX 取不到按钮名（`missing value`）；
  这期间别按 Esc，否则会把确认框取消掉（等于没复原）。

---

## 5. 清空整条和弦轨（安全版本）

```
点行首「和弦 ⌄」→ 「选择所有和弦」→ Delete
```

**不要用 `⌘A`**：`⌘A` 可能连片段一起选中，接着一个误触的 `⌘T` 就把片段切碎了。
「选择所有和弦」只选和弦，是安全版本。

---

## 6. 完整示例（8 小节）

目标：

```
小节  1     2      3       4     5       6     7      8
和弦  C     Em/B   C7/B♭   F/A   Fm/A♭   C/G   D/G♭   G
```

步骤：

1. `G` 确认和弦轨可见；
2. 点行首 ⌄ → `选择所有和弦` → `Delete`（清空旧内容）；
3. `n = 1..8`：点标尺第 n 小节 → 读 LCD 确认 `n 1 1 001` → 点 ⊕；
4. 双击第 2~8 小节的和弦段，依次输入 `Em/B`、`C7/Bb`、`F/A`、`Fm/Ab`、`C/G`、`D/Gb`、`G`
   （第 1 小节默认就是 `C`，可不动），每改完一个按 `Esc`；
5. 读和弦行核对：`C | Em/B | C7/B♭ | F/A | Fm/A♭ | C/G | D/F♯ | G`
   （`D/Gb` 会显示成 `D/F♯`，等音，正常）；
6. 用 `scan` 对齐验证：和弦边界与片段边界应落在同一像素（同一条小节线）。

验证像素一致：

```bash
screencapture -x -R1330,372,120,26 /tmp/a.png   # 和弦行
screencapture -x -R1330,412,120,30 /tmp/b.png   # 片段行
./tools/scan /tmp/a.png 12
./tools/scan /tmp/b.png 15
# 两行的颜色突变 x 相同 → 对齐无误
```

---

## 7. 和弦轨与伴奏乐手的关系

- Logic 11 的**伴奏乐手（Session Player）片段会跟随和弦轨**重新生成演奏；
- 所以改完和弦后，伴奏轨的演奏内容可能变化，这是预期行为；
- 想复制「和弦 + 片段」到后面几小节：`编辑 › 选择 › 全部` → `编辑 › 重复 › 一次`（⌘R）
  —— 实测这会**同时**复制片段和和弦，且自动对齐到下一小节，比"拷贝+定位播放头+粘贴"省事。

---

## 8. 速查

```bash
# 显示/隐藏全局轨道
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "g"'

# 读播放头位置
screencapture -x -R1185,55,180,40 /tmp/l.png && sips -z 90 405 /tmp/l.png --out /tmp/l_u.png && ./tools/ocr /tmp/l_u.png --lang en-US

# 建和弦（第 n 小节）
cliclick c:$((983 + (n-1)*48)),170   # 定位
cliclick c:963,378                    # ⊕

# 改名
cliclick dc:1007,378                  # 双击第 n 小节的和弦段（x = 1007+(n-1)*48）
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "a" using command down'
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to keystroke "Em/B"'
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to key code 36'   # Return
osascript -e 'tell application "System Events" to tell process "Logic Pro X" to key code 53'   # Esc
```

---

## 9. 注意事项

- 全流程要求**和弦轨获得焦点**的操作（`⌘T`、双击）与片段区的焦点是互斥的，务必分步验证；
- 改名前先备份工程（`File › 存储为…` 或复制 `.logicx`）；
- 和弦名输入后立即截图核对，避免 Logic 的自动拼写/等音改写造成误解；
- 若界面语言不是中文，请把本文档里的菜单名对应换成你的语言版本（快捷键不变）。

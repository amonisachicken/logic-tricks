// pi-midi — 通过 CoreMIDI 建一个虚拟 MIDI 源，把音符"弹"给 Logic Pro（或任何 MIDI 接收端）
//
// 编译：swiftc -O -o ~/skills/pi-midi ~/skills/pi-midi.swift
//
// 用法：
//   pi-midi list                          # 列出系统 MIDI 目标/源
//   pi-midi note <音名> [力度] [时长秒]    # 弹单音，如 pi-midi note C4 100 1.0
//   pi-midi chords                        # 弹内置 8 小节和弦进行
//   pi-midi raw <b1,b2,b3>                # 发原始字节，如 pi-midi raw 144,60,100
//
// 原理：MIDISourceCreate 建一个名为 "pi-keys" 的虚拟源，Logic 会把它当成一个 MIDI 输入设备。

import Foundation
import CoreMIDI

// ---------- CoreMIDI 基础 ----------
var client = MIDIClientRef()
var source = MIDIEndpointRef()

func setupMIDI() {
    let st1 = MIDIClientCreateWithBlock("pi-client" as CFString, &client, nil)
    guard st1 == noErr else { FileHandle.standardError.write("MIDIClientCreate 失败: \(st1)\n".data(using: .utf8)!); exit(1) }
    let st2 = MIDISourceCreate(client, "pi-keys" as CFString, &source)
    guard st2 == noErr else { FileHandle.standardError.write("MIDISourceCreate 失败: \(st2)\n".data(using: .utf8)!); exit(1) }
    // 给系统一点时间注册这个虚拟端口
    usleep(300_000)
}

func send(_ bytes: [UInt8]) {
    let listSize = 1024
    let buf = UnsafeMutableRawPointer.allocate(byteCount: listSize, alignment: 8)
    defer { buf.deallocate() }
    let listPtr = buf.bindMemory(to: MIDIPacketList.self, capacity: 1)
    var packet = MIDIPacketListInit(listPtr)
    packet = MIDIPacketListAdd(listPtr, listSize, packet, 0, bytes.count, bytes)
    MIDIReceived(source, listPtr)
}

func noteOn(_ note: Int, _ vel: Int = 96, ch: Int = 0) { send([UInt8(0x90 | ch), UInt8(note), UInt8(vel)]) }
func noteOff(_ note: Int, ch: Int = 0) { send([UInt8(0x80 | ch), UInt8(note), 0]) }
func allOff(ch: Int = 0) { send([UInt8(0xB0 | ch), 123, 0]) }

// ---------- 音名 → MIDI 号 ----------
let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
func midiNumber(_ s: String) -> Int? {
    var name = s.uppercased()
    var oct = ""
    while let last = name.last, last.isNumber { oct = String(last) + oct; name.removeLast() }
    guard let base = names.firstIndex(of: name), let o = Int(oct) else { return nil }
    return (o + 1) * 12 + base
}

// ---------- 内置：8 小节和弦进行 ----------
// (小节名, 低音, 上方和弦音)
let progression: [(String, Int, [Int])] = [
    ("C",      36, [60, 64, 67]),        // C2 | C4 E4 G4
    ("Em/B",   35, [64, 67, 71]),        // B1 | E4 G4 B4
    ("C7/Bb",  34, [60, 64, 67, 70]),    // Bb1| C4 E4 G4 Bb4
    ("F/A",    33, [65, 69, 72]),        // A1 | F4 A4 C5
    ("Fm/Ab",  32, [65, 68, 72]),        // Ab1| F4 Ab4 C5
    ("C/G",    31, [60, 64, 67]),        // G1 | C4 E4 G4
    ("D/Gb",   30, [62, 66, 69]),        // Gb1| D4 F#4 A4
    ("G",      31, [62, 67, 71]),        // G1 | D4 G4 B4
]

func playChord(_ bass: Int, _ notes: [Int], dur: Double, vel: Int = 88) {
    noteOn(bass, vel)
    notes.forEach { noteOn($0, vel) }
    Thread.sleep(forTimeInterval: dur)
    noteOff(bass)
    notes.forEach { noteOff($0) }
}

// ---------- main ----------
let a = CommandLine.arguments
let cmd = a.count > 1 ? a[1] : "chords"

setupMIDI()

switch cmd {
case "list":
    print("MIDI 目标（Logic 会看到这里的源）：")
    for i in 0..<MIDIGetNumberOfSources() {
        let ep = MIDIGetSource(i)
        var cf: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(ep, kMIDIPropertyDisplayName, &cf)
        if let s = cf?.takeRetainedValue() as String? { print("  [\(i)] \(s)") }
    }
    print("虚拟源 \"pi-keys\" 已创建（脚本退出后自动消失）")

case "note":
    guard a.count > 2, let n = midiNumber(a[2]) else { FileHandle.standardError.write("用法: pi-midi note C4 [vel] [sec]\n".data(using: .utf8)!); exit(2) }
    let vel = a.count > 3 ? (Int(a[3]) ?? 96) : 96
    let dur = a.count > 4 ? (Double(a[4]) ?? 1.0) : 1.0
    print("note \(a[2]) = MIDI \(n), vel \(vel), \(dur)s")
    noteOn(n, vel); Thread.sleep(forTimeInterval: dur); noteOff(n)

case "raw":
    guard a.count > 2 else { FileHandle.standardError.write("用法: pi-midi raw 144,60,100\n".data(using: .utf8)!); exit(2) }
    let bytes = a[2].split(separator: ",").compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
    print("send \(bytes)")
    send(bytes)

default: // chords
    let beat = a.count > 2 ? (Double(a[2]) ?? 1.5) : 1.5
    let delay = a.count > 3 ? (Double(a[3]) ?? 0.0) : 0.0
    if delay > 0 {
        print("延迟 \(delay)s 后开始（等 Logic 的预备拍）")
        Thread.sleep(forTimeInterval: delay)
    }
    print("弹奏 8 小节和弦进行，每小节 \(beat) 秒：")
    for (name, bass, notes) in progression {
        print("  \(name)\tbass=\(bass) notes=\(notes)")
        playChord(bass, notes, dur: beat)
    }
    allOff()
    print("结束")
}

allOff()
Thread.sleep(forTimeInterval: 0.3)

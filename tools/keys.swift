// keys — 按住若干物理键 N 秒（CGEvent 注入，可同时按住多键 → 弹和弦）
// 编译：swiftc -O -o ~/skills/keys ~/skills/keys.swift
// 用法：keys 0,2,5 2.0        # 按住 A+D+G（Logic 音乐键入里 = C 大三和弦）2 秒
//        keys 0 0.3            # 单击一下
import Cocoa
let a = CommandLine.arguments
guard a.count > 1 else { print("用法: keys <keycode[,keycode...]> [秒]"); exit(2) }
let codes = a[1].split(separator: ",").compactMap { UInt16($0.trimmingCharacters(in: .whitespaces)) }
let hold = a.count > 2 ? (Double(a[2]) ?? 1.0) : 1.0
let src = CGEventSource(stateID: .hidSystemState)
for c in codes {
    if let d = CGEvent(keyboardEventSource: src, virtualKey: c, keyDown: true) { d.post(tap: .cghidEventTap) }
    usleep(40_000)
}
Thread.sleep(forTimeInterval: hold)
for c in codes {
    if let u = CGEvent(keyboardEventSource: src, virtualKey: c, keyDown: false) { u.post(tap: .cghidEventTap) }
    usleep(20_000)
}
print("按住 keycode \(codes) \(hold)s")

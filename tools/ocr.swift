// ocr — 基于 macOS Vision 框架的本地 OCR（无需安装任何第三方库/模型）
//
// 编译（一次性，约 5 秒）：
//   swiftc -O -o ocr ocr.swift
//
// 用法：
//   ./ocr <图片路径> [--lang zh-Hans,en-US] [--json] [--boxes]
//
// 参数：
//   --lang   逗号分隔的语言列表，默认 "zh-Hans,en-US"。支持 zh-Hans/zh-Hant/en-US/ja-JP/ko-KR 等
//   --json   输出 JSON（含文本、置信度、坐标）
//   --boxes  输出每行文本外，附带归一化坐标框 x,y,w,h（左下角为原点）
//
// 注意：VNRecognizeTextRequest 的语言能力取决于系统 OCR 模型（macOS 13 已内置中英文）

import Foundation
import Vision
import AppKit

struct Args {
    var path: String = ""
    var langs: [String] = ["zh-Hans", "en-US"]
    var json = false
    var boxes = false
}

func parseArgs() -> Args {
    var a = Args()
    let av = CommandLine.arguments.dropFirst()
    var it = av.makeIterator()
    while let arg = it.next() {
        switch arg {
        case "--lang":
            if let v = it.next() {
                a.langs = v.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }
        case "--json": a.json = true
        case "--boxes": a.boxes = true
        case "-h", "--help":
            print("用法: ocr <图片路径> [--lang zh-Hans,en-US] [--json] [--boxes]")
            exit(0)
        default: a.path = arg
        }
    }
    return a
}

let args = parseArgs()

guard !args.path.isEmpty else {
    FileHandle.standardError.write("用法: ocr <图片路径> [--lang zh-Hans,en-US] [--json] [--boxes]\n".data(using: .utf8)!)
    exit(2)
}

let url = URL(fileURLWithPath: (args.path as NSString).expandingTildeInPath)
guard let image = NSImage(contentsOf: url) else {
    FileHandle.standardError.write("无法读取图片: \(args.path)\n".data(using: .utf8)!)
    exit(1)
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage else {
    FileHandle.standardError.write("无法解码图片: \(args.path)\n".data(using: .utf8)!)
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = args.langs

let handler = VNImageRequestHandler(cgImage: cg, options: [:])
let t0 = Date()
do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write("OCR 失败: \(error)\n".data(using: .utf8)!)
    exit(1)
}
let elapsed = Date().timeIntervalSince(t0)

let observations = request.results ?? []
let lines: [(String, Float, CGRect)] = observations.compactMap { obs in
    guard let top = obs.topCandidates(1).first else { return nil }
    return (top.string, top.confidence, obs.boundingBox)
}

if args.json {
    var out: [[String: Any]] = []
    for (text, conf, box) in lines {
        out.append([
            "text": text,
            "confidence": Double(conf),
            "x": Double(box.origin.x), "y": Double(box.origin.y),
            "w": Double(box.size.width), "h": Double(box.size.height),
        ])
    }
    let payload: [String: Any] = [
        "file": url.lastPathComponent,
        "languages": args.langs,
        "count": out.count,
        "elapsed": elapsed,
        "lines": out,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: payload,
                                              options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: data, encoding: .utf8) {
        print(s)
    }
} else {
    for (text, conf, box) in lines {
        if args.boxes {
            let b = String(format: "x=%.3f y=%.3f w=%.3f h=%.3f", box.origin.x, box.origin.y,
                           box.size.width, box.size.height)
            print("[\(b)] (conf \(String(format: "%.2f", conf))) \(text)")
        } else {
            print(text)
        }
    }
    FileHandle.standardError.write(String(format: "-- %d 行, %.3fs, 语言 %@\n",
        lines.count, elapsed, args.langs.joined(separator: ",")).data(using: .utf8)!)
}

import AppKit
// 用法: scan <png> <y> [tolerance]
let a = CommandLine.arguments
guard a.count >= 3, let img = NSImage(contentsOfFile: a[1]),
      let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage, let y = Int(a[2]), y < cg.height else { print("bad args"); exit(1) }
let w = cg.width
var buf = [UInt8](repeating: 0, count: w*4)
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: &buf, width: w, height: 1, bitsPerComponent: 8, bytesPerRow: w*4,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(-y))
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
// 找颜色突变点
var prev: (Int,Int,Int)? = nil
var out: [String] = []
for x in 0..<w {
    let r = Int(buf[x*4]), g = Int(buf[x*4+1]), b = Int(buf[x*4+2])
    if let p = prev {
        let d = abs(r-p.0)+abs(g-p.1)+abs(b-p.2)
        if d > 24 { out.append("\(x)(\(r),\(g),\(b))") }
    } else { out.append("\(x)(\(r),\(g),\(b))") }
    prev = (r,g,b)
}
print(out.joined(separator: " "))

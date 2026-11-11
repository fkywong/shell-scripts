#!/usr/bin/env swift
// Draw an emoji or a small image over the bottom-right corner of a base image, then center both on
// a square canvas.
//
// Usage: compose-icon.swift <base image> <out.png> [emoji or image path=🔐] [emoji pt or image px=136] [shift right px=32] [margin px=8]
import AppKit

let args = CommandLine.arguments
func arg(_ i: Int, _ d: String) -> String { args.count > i ? args[i] : d }
guard args.count >= 3 else {
  print("usage: compose-icon.swift <base image> <out.png> [emoji or image path=🔐] [emoji pt or image px=136] [shift right px=32] [margin px=8]")
  exit(1)
}
let base = NSImage(contentsOf: URL(fileURLWithPath: args[1]))!
let emoji = arg(3, "🔐")
let emojiSize = CGFloat(Double(arg(4, "136"))!)
let lockShift = CGFloat(Double(arg(5, "32"))!)
let margin = Int(arg(6, "8"))!

func canvas(_ n: Int) -> NSBitmapImageRep {
  NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

// Lay out on a large scratch canvas: base fitted into 224x224 (224 wide for a landscape image),
// top-left of a 256 layout, with the emoji in its lower right.
let big = 512, o: CGFloat = 128
let scratch = canvas(big)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scratch)
let aspect = base.size.height / base.size.width
let w: CGFloat = aspect <= 1 ? 224 : 224 / aspect, h = w * aspect
base.draw(in: NSRect(x: o + 4, y: o + 256 - h - 24, width: w, height: h))
if FileManager.default.fileExists(atPath: emoji) {
  // An image instead of an emoji: drawn as an emojiSize-px square in the same corner.
  let img = NSImage(contentsOf: URL(fileURLWithPath: emoji))!
  img.draw(in: NSRect(x: o + 256 - emojiSize + 2 + lockShift, y: o - 4, width: emojiSize, height: emojiSize))
} else {
  let mark = NSAttributedString(string: emoji, attributes: [.font: NSFont(name: "Apple Color Emoji", size: emojiSize)!])
  let b = mark.size()
  mark.draw(at: NSPoint(x: o + 256 - b.width + 2 + lockShift, y: o - 4))
}
NSGraphicsContext.restoreGraphicsState()

// Bounding box of everything drawn (bitmap rows run top-down).
var minX = big, minY = big, maxX = -1, maxY = -1
for y in 0..<big { for x in 0..<big where scratch.colorAt(x: x, y: y)!.alphaComponent > 0.02 {
  minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
} }
let bw = maxX - minX + 1, bh = maxY - minY + 1
let side = max(bw, bh) + 2 * margin

// Center that box on a square canvas at the same scale.
let out = canvas(side)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
let src = NSImage(size: NSSize(width: big, height: big)); src.addRepresentation(scratch)
let dx = CGFloat(side - bw) / 2 - CGFloat(minX)
let dy = CGFloat(side - bh) / 2 - CGFloat(big - 1 - maxY)
src.draw(in: NSRect(x: dx, y: dy, width: CGFloat(big), height: CGFloat(big)))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("canvas \(side)x\(side), content \(bw)x\(bh)")

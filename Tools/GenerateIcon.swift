#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.dropFirst().first
    ?? "Resources/Assets.xcassets/AppIcon.appiconset"
let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create drawing context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let backgroundRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let backgroundPath = NSBezierPath(
    roundedRect: backgroundRect,
    xRadius: 208,
    yRadius: 208
)
let backgroundGradient = NSGradient(colors: [
    NSColor(red: 0.04, green: 0.16, blue: 0.30, alpha: 1),
    NSColor(red: 0.05, green: 0.40, blue: 0.76, alpha: 1)
])!
backgroundGradient.draw(in: backgroundPath, angle: -45)

context.saveGState()
backgroundPath.addClip()
for index in 1...4 {
    let inset = CGFloat(index) * 118
    NSColor.white.withAlphaComponent(0.055).setStroke()
    let line = NSBezierPath()
    line.lineWidth = 2
    line.move(to: NSPoint(x: 64 + inset, y: 64))
    line.line(to: NSPoint(x: 64 + inset, y: 960))
    line.stroke()
    line.removeAllPoints()
    line.move(to: NSPoint(x: 64, y: 64 + inset))
    line.line(to: NSPoint(x: 960, y: 64 + inset))
    line.stroke()
}
context.restoreGState()

let clockCenter = CGPoint(x: 512, y: 548)
let clockRadius: CGFloat = 250
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: NSColor.black.withAlphaComponent(0.28).cgColor)
NSColor.white.withAlphaComponent(0.96).setFill()
NSBezierPath(
    ovalIn: CGRect(
        x: clockCenter.x - clockRadius,
        y: clockCenter.y - clockRadius,
        width: clockRadius * 2,
        height: clockRadius * 2
    )
).fill()
context.setShadow(offset: .zero, blur: 0)

NSColor(red: 0.04, green: 0.21, blue: 0.38, alpha: 1).setStroke()
for index in 0..<12 {
    let angle = CGFloat(index) * .pi / 6
    let inner = clockRadius - (index % 3 == 0 ? 36 : 24)
    let outer = clockRadius - 12
    let path = NSBezierPath()
    path.lineWidth = index % 3 == 0 ? 10 : 6
    path.lineCapStyle = .round
    path.move(to: NSPoint(
        x: clockCenter.x + sin(angle) * inner,
        y: clockCenter.y + cos(angle) * inner
    ))
    path.line(to: NSPoint(
        x: clockCenter.x + sin(angle) * outer,
        y: clockCenter.y + cos(angle) * outer
    ))
    path.stroke()
}

let handColor = NSColor(red: 0.04, green: 0.24, blue: 0.45, alpha: 1)
handColor.setStroke()
let hourHand = NSBezierPath()
hourHand.lineWidth = 28
hourHand.lineCapStyle = .round
hourHand.move(to: NSPoint(x: clockCenter.x, y: clockCenter.y))
hourHand.line(to: NSPoint(x: clockCenter.x - 104, y: clockCenter.y + 94))
hourHand.stroke()

let minuteHand = NSBezierPath()
minuteHand.lineWidth = 22
minuteHand.lineCapStyle = .round
minuteHand.move(to: NSPoint(x: clockCenter.x, y: clockCenter.y))
minuteHand.line(to: NSPoint(x: clockCenter.x + 92, y: clockCenter.y + 148))
minuteHand.stroke()

handColor.setFill()
NSBezierPath(ovalIn: CGRect(x: 490, y: 526, width: 44, height: 44)).fill()

let badgeRect = CGRect(x: 552, y: 230, width: 288, height: 220)
let badgePath = NSBezierPath(
    roundedRect: badgeRect,
    xRadius: 76,
    yRadius: 76
)
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor(red: 0.07, green: 0.72, blue: 0.49, alpha: 1).setFill()
badgePath.fill()
context.setShadow(offset: .zero, blur: 0)

NSColor.white.setStroke()
let check = NSBezierPath()
check.lineWidth = 34
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: 620, y: 335))
check.line(to: NSPoint(x: 686, y: 278))
check.line(to: NSPoint(x: 784, y: 382))
check.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to encode icon")
}

let fileManager = FileManager.default
try fileManager.createDirectory(
    atPath: outputDirectory,
    withIntermediateDirectories: true
)
let masterURL = URL(fileURLWithPath: outputDirectory)
    .appending(path: "icon_512x512@2x.png")
try png.write(to: masterURL, options: .atomic)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512)
]

for (name, size) in variants {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = [
        "-z", String(size), String(size),
        masterURL.path,
        "--out",
        URL(fileURLWithPath: outputDirectory).appending(path: name).path
    ]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        fatalError("Unable to generate \(name)")
    }
}

print("Generated macOS icon set in \(outputDirectory)")

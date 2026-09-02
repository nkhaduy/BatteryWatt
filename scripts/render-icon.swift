import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("usage: render-icon.swift <iconset-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in sizes {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "BatteryWattIcon", code: 1)
    }

    let width = CGFloat(size)
    let background = CGColor(red: 0.075, green: 0.102, blue: 0.125, alpha: 1)
    let battery = CGColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1)
    let graphite = CGColor(red: 0.10, green: 0.14, blue: 0.17, alpha: 1)
    let accent = CGColor(red: 0.96, green: 0.75, blue: 0.28, alpha: 1)

    context.setFillColor(background)
    context.addPath(CGPath(roundedRect: CGRect(x: width * 0.08, y: width * 0.08, width: width * 0.84, height: width * 0.84), cornerWidth: width * 0.19, cornerHeight: width * 0.19, transform: nil))
    context.fillPath()

    let body = CGRect(x: width * 0.23, y: width * 0.17, width: width * 0.54, height: width * 0.57)
    context.setFillColor(battery)
    context.addPath(CGPath(roundedRect: body, cornerWidth: width * 0.10, cornerHeight: width * 0.10, transform: nil))
    context.fillPath()

    let inner = body.insetBy(dx: width * 0.035, dy: width * 0.035)
    context.setFillColor(graphite)
    context.addPath(CGPath(roundedRect: inner, cornerWidth: width * 0.075, cornerHeight: width * 0.075, transform: nil))
    context.fillPath()

    let terminal = CGRect(x: width * 0.40, y: width * 0.74, width: width * 0.20, height: width * 0.08)
    context.setFillColor(battery)
    context.addPath(CGPath(roundedRect: terminal, cornerWidth: width * 0.025, cornerHeight: width * 0.025, transform: nil))
    context.fillPath()

    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: width * 0.57, y: width * 0.64))
    bolt.addLine(to: CGPoint(x: width * 0.39, y: width * 0.43))
    bolt.addLine(to: CGPoint(x: width * 0.50, y: width * 0.43))
    bolt.addLine(to: CGPoint(x: width * 0.43, y: width * 0.27))
    bolt.addLine(to: CGPoint(x: width * 0.63, y: width * 0.49))
    bolt.addLine(to: CGPoint(x: width * 0.51, y: width * 0.49))
    bolt.closeSubpath()
    context.setFillColor(accent)
    context.addPath(bolt)
    context.fillPath()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            outputDirectory.appendingPathComponent(name) as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
          ) else {
        throw NSError(domain: "BatteryWattIcon", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "BatteryWattIcon", code: 3)
    }
}

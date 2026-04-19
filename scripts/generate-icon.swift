#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Point {
    var x: CGFloat
    var y: CGFloat
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/BrowserRouter.icns")
let baseSize: CGFloat = 1024

let fileManager = FileManager.default
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func render(size: Int) throws -> CGImage {
    let width = size
    let height = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "BrowserRouterIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context"])
    }

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(size) / baseSize, y: CGFloat(size) / baseSize)

    let canvas = CGRect(x: 0, y: 0, width: baseSize, height: baseSize)
    let background = CGPath(roundedRect: canvas.insetBy(dx: 8, dy: 8), cornerWidth: 180, cornerHeight: 180, transform: nil)
    let backgroundGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [rgb(0.998, 0.999, 1.0), rgb(0.940, 0.946, 0.957)] as CFArray,
        locations: [0, 1]
    )!

    context.saveGState()
    context.addPath(background)
    context.clip()
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: baseSize * 0.5, y: 0),
        end: CGPoint(x: baseSize * 0.5, y: baseSize),
        options: []
    )
    context.restoreGState()

    context.setStrokeColor(rgb(0.83, 0.85, 0.88))
    context.setLineWidth(2.5)
    context.addPath(background)
    context.strokePath()

    let arrowColor = rgb(0.29, 0.53, 0.84)
    context.setFillColor(arrowColor)
    context.setStrokeColor(arrowColor)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    func drawBranch(from start: CGPoint, through control1: CGPoint, to end: CGPoint) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: CGPoint(x: end.x - (end.x - control1.x) * 0.55, y: end.y - (end.y - control1.y) * 0.55))
        context.saveGState()
        context.addPath(path)
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: rgb(0.20, 0.30, 0.50, 0.15))
        context.setLineWidth(86)
        context.strokePath()
        context.restoreGState()
    }

    func drawArrowHead(tip: CGPoint, control: CGPoint, length: CGFloat = 68, width: CGFloat = 56) {
        let angle = atan2(tip.y - control.y, tip.x - control.x)
        let back = CGPoint(x: tip.x - cos(angle) * length, y: tip.y - sin(angle) * length)
        let perp = CGPoint(x: -sin(angle) * width * 0.5, y: cos(angle) * width * 0.5)
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: back.x + perp.x, y: back.y + perp.y))
        path.addLine(to: CGPoint(x: back.x - perp.x, y: back.y - perp.y))
        path.closeSubpath()
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: rgb(0.22, 0.32, 0.54, 0.14))
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    let trunk = CGMutablePath()
    trunk.move(to: CGPoint(x: 188, y: 515))
    trunk.addLine(to: CGPoint(x: 438, y: 515))
    context.addPath(trunk)
    context.setLineWidth(86)
    context.strokePath()

    drawBranch(
        from: CGPoint(x: 438, y: 515),
        through: CGPoint(x: 532, y: 494),
        to: CGPoint(x: 628, y: 356)
    )
    drawArrowHead(
        tip: CGPoint(x: 628, y: 356),
        control: CGPoint(x: 570, y: 422)
    )

    drawBranch(
        from: CGPoint(x: 438, y: 515),
        through: CGPoint(x: 532, y: 556),
        to: CGPoint(x: 624, y: 676)
    )
    drawArrowHead(
        tip: CGPoint(x: 624, y: 676),
        control: CGPoint(x: 566, y: 604)
    )

    let iconTone = rgb(0.51, 0.60, 0.71)
    let iconToneDark = rgb(0.38, 0.46, 0.58)
    let iconGradient = CGGradient(colorsSpace: colorSpace, colors: [iconTone, iconToneDark] as CFArray, locations: [0, 1])!

    func fillRoundedRect(_ rect: CGRect, radius: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            iconGradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
        context.setStrokeColor(rgb(0.33, 0.39, 0.48))
        context.setLineWidth(2)
        context.addPath(path)
        context.strokePath()
    }

    context.setFillColor(iconTone)
    context.setStrokeColor(rgb(0.33, 0.39, 0.48))

    let circleRect = CGRect(x: 686, y: 302, width: 164, height: 164)
    let circlePath = CGPath(ellipseIn: circleRect, transform: nil)
    context.saveGState()
    context.addPath(circlePath)
    context.clip()
    context.drawLinearGradient(
        iconGradient,
        start: CGPoint(x: circleRect.midX, y: circleRect.minY),
        end: CGPoint(x: circleRect.midX, y: circleRect.maxY),
        options: []
    )
    context.restoreGState()
    context.setLineWidth(2)
    context.addPath(circlePath)
    context.strokePath()

    fillRoundedRect(CGRect(x: 684, y: 578, width: 156, height: 156), radius: 20)

    guard let image = context.makeImage() else {
        throw NSError(domain: "BrowserRouterIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to render image"])
    }
    return image
}

func writeICNS(_ images: [(CGImage, Int)], to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.icns.identifier as CFString, images.count, nil) else {
        throw NSError(domain: "BrowserRouterIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create ICNS destination"])
    }
    for (image, _) in images.sorted(by: { $0.1 < $1.1 }) {
        CGImageDestinationAddImage(destination, image, nil)
    }
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "BrowserRouterIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to write ICNS"])
    }
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let images = try sizes.map { size -> (CGImage, Int) in
    (try render(size: size), size)
}

try writeICNS(images, to: outputURL)

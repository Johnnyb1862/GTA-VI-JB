//
//  generate_app_icons.swift
//  GTA VI JB
//
//  Renders the GTA VI JB app icon from the same palm photograph used by the
//  theme and the userspace reboot splash: the photo cropped to a square, a
//  dark scrim for contrast, and "GTA6JB" across the bottom.
//
//  Run from the repo root:  swift scripts/generate_app_icons.swift
//  Writes every size listed in AppIcon.appiconset/Contents.json in place.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

let sourceURL = repoRoot.appendingPathComponent("Application/Dopamine/Assets.xcassets/Background/Background_GTAVI.imageset/gtavi.jpg")
let iconSetURL = repoRoot.appendingPathComponent("Application/Dopamine/Assets.xcassets/AppIcon.appiconset")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("generate_app_icons: \(message)\n".data(using: .utf8)!)
    exit(1)
}

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    fail("no sRGB color space")
}

guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    fail("cannot read \(sourceURL.path)")
}

// Square center crop of the palm photograph
let side = min(sourceImage.width, sourceImage.height)
let cropRect = CGRect(x: (sourceImage.width - side) / 2,
                      y: (sourceImage.height - side) / 2,
                      width: side,
                      height: side)

guard let cropped = sourceImage.cropping(to: cropRect) else {
    fail("cannot crop source image")
}

// Render the master at 1024 so every size is a clean downscale of one drawing
let masterSize = 1024

guard let master = CGContext(data: nil,
                             width: masterSize,
                             height: masterSize,
                             bitsPerComponent: 8,
                             bytesPerRow: 0,
                             space: colorSpace,
                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fail("cannot create master context")
}

master.interpolationQuality = .high
master.draw(cropped, in: CGRect(x: 0, y: 0, width: masterSize, height: masterSize))

// Scrim: clear at the top, dark at the bottom, so the text reads over the photo
let clearColor = CGColor(colorSpace: colorSpace, components: [0, 0, 0, 0])!
let darkColor = CGColor(colorSpace: colorSpace, components: [0, 0, 0, 0.82])!
if let scrim = CGGradient(colorsSpace: colorSpace,
                          colors: [clearColor, darkColor] as CFArray,
                          locations: nil) {
    master.drawLinearGradient(scrim,
                              start: CGPoint(x: 0, y: CGFloat(masterSize)),
                              end: CGPoint(x: 0, y: 0),
                              options: [])
}

// "GTA6JB" across the bottom
let fontSize = CGFloat(masterSize) * 0.19
let font = CTFontCreateWithName("HelveticaNeue-CondensedBlack" as CFString, fontSize, nil)
let whiteColor = CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!

let attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): whiteColor,
    NSAttributedString.Key(kCTKernAttributeName as String): CGFloat(masterSize) * 0.002,
]

let attributed = NSAttributedString(string: "GTA6JB", attributes: attributes)
let line = CTLineCreateWithAttributedString(attributed)

var ascent: CGFloat = 0
var descent: CGFloat = 0
var leading: CGFloat = 0
let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

master.textPosition = CGPoint(x: (CGFloat(masterSize) - textWidth) / 2.0,
                              y: CGFloat(masterSize) * 0.13)
CTLineDraw(line, master)

guard let masterImage = master.makeImage() else {
    fail("cannot render master image")
}

// Every file the asset catalog references, with the pixel size it expects
let outputs: [(String, Int)] = [
    ("Icon-Notification@2x.png", 40),
    ("Icon-Notification@3x.png", 60),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small@3x.png", 87),
    ("Icon-38@2x.png", 76),
    ("Icon-38@3x.png", 114),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-Small-40@3x.png", 120),
    ("Icon-Small-40@3x 1.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-64@2x.png", 128),
    ("Icon-64@3x.png", 192),
    ("Icon-68@2x.png", 136),
    ("Icon-76@2x.png", 152),
    ("Icon-83.5@2x.png", 167),
]

for (filename, size) in outputs {
    guard let context = CGContext(data: nil,
                                  width: size,
                                  height: size,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fail("cannot create \(size)x\(size) context")
    }

    context.interpolationQuality = .high
    context.draw(masterImage, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard let image = context.makeImage() else {
        fail("cannot render \(filename)")
    }

    let destinationURL = iconSetURL.appendingPathComponent(filename)
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL,
                                                            UTType.png.identifier as CFString,
                                                            1,
                                                            nil) else {
        fail("cannot open \(filename) for writing")
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("cannot write \(filename)")
    }

    print("generate_app_icons: wrote \(filename) (\(size)x\(size))")
}

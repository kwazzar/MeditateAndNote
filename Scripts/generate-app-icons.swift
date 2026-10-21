#!/usr/bin/env swift
//
// Generates the app icon for iOS and Android from one layout.
//
//   swift Scripts/generate-app-icons.swift
//
// Output:
//   iOS       Assets.xcassets/AppIcon.appiconset/AppIcon.png  (1024, opaque, no alpha)
//   Android   res/mipmap-*/ic_launcher_foreground.png         (transparent, 108dp canvas)
//
// Colours mirror the darkZen theme (MainTheme.swift / MnColors.kt):
// background #0F1424, letters white, ampersand accent #DB34F2.
//
// Font: Inter (SIL OFL 1.1) — https://github.com/google/fonts/tree/main/ofl/inter
// Downloaded once into Scripts/.icons-cache/ (gitignored, not redistributed).

import CoreGraphics
import CoreText
import Foundation
import ImageIO

// Fractions of the canvas width occupied by "M&N".
// Android's adaptive canvas is 108dp with only the centre 72dp visible, so its
// fraction is smaller to look the same size after masking (0.53 * 108 / 72 ≈ 0.80).
let iosGlyphWidth: Double = 0.80
let androidGlyphWidth: Double = 0.53

let background = CGColor(red: 0x0F / 255.0, green: 0x14 / 255.0, blue: 0x24 / 255.0, alpha: 1)
let letterColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
let accentColor = CGColor(red: 0xDB / 255.0, green: 0x34 / 255.0, blue: 0xF2 / 255.0, alpha: 1)

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repoRoot = scriptDir.deletingLastPathComponent()
let cacheDir = scriptDir.appendingPathComponent(".icons-cache")

// MARK: - Font

func download(_ url: URL, to destination: URL) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var payload: Data?
    var failure: Error?
    URLSession.shared.dataTask(with: url) { data, _, error in
        payload = data
        failure = error
        semaphore.signal()
    }.resume()
    semaphore.wait()
    if let failure { throw failure }
    guard let payload, !payload.isEmpty else {
        throw NSError(domain: "icons", code: 1, userInfo: [NSLocalizedDescriptionKey: "empty download: \(url)"])
    }
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try payload.write(to: destination)
}

func interFont(weight: Double) throws -> CTFont {
    let fontURL = cacheDir.appendingPathComponent("Inter.ttf")
    if !FileManager.default.fileExists(atPath: fontURL.path) {
        print("downloading Inter → \(fontURL.path)")
        let base = "https://github.com/google/fonts/raw/main/ofl/inter/"
        try download(URL(string: base + "Inter%5Bopsz%2Cwght%5D.ttf")!, to: fontURL)
        try download(URL(string: base + "OFL.txt")!, to: cacheDir.appendingPathComponent("OFL.txt"))
    }
    guard let provider = CGDataProvider(url: fontURL as CFURL), let cgFont = CGFont(provider) else {
        throw NSError(domain: "icons", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot load \(fontURL.path)"])
    }
    let base = CTFontCreateWithGraphicsFont(cgFont, 100, nil, nil)
    let axes = CTFontCopyVariationAxes(base) as? [[CFString: Any]] ?? []
    let weightAxis = axes.first { ($0[kCTFontVariationAxisNameKey] as? String) == "Weight" }
    guard let axisID = weightAxis?[kCTFontVariationAxisIdentifierKey] as? Int else {
        throw NSError(domain: "icons", code: 3, userInfo: [NSLocalizedDescriptionKey: "no Weight axis in Inter"])
    }
    let descriptor = CTFontDescriptorCreateCopyWithAttributes(
        CTFontCopyFontDescriptor(base),
        [kCTFontVariationAttribute: [axisID: weight]] as CFDictionary
    )
    return CTFontCreateWithFontDescriptor(descriptor, 100, nil)
}

// MARK: - Drawing

/// "M&N" as one line: white letters, accent ampersand.
func monogramLine(fontSize: CGFloat, font: CTFont) -> CTLine {
    let sized = CTFontCreateCopyWithAttributes(font, fontSize, nil, nil)
    let string = CFAttributedStringCreateMutable(nil, 0)!
    CFAttributedStringReplaceString(string, CFRange(location: 0, length: 0), "M&N" as CFString)
    CFAttributedStringSetAttribute(string, CFRange(location: 0, length: 3), kCTFontAttributeName, sized)
    CFAttributedStringSetAttribute(string, CFRange(location: 0, length: 3), kCTForegroundColorAttributeName, letterColor)
    CFAttributedStringSetAttribute(string, CFRange(location: 1, length: 1), kCTForegroundColorAttributeName, accentColor)
    return CTLineCreateWithAttributedString(string)
}

func lineWidth(_ line: CTLine) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

/// Renders M&N centred on a square canvas. Pass `background: nil` for a
/// transparent layer (Android adaptive foreground).
func render(canvas: Int, glyphWidth: Double, background fill: CGColor?, font: CTFont) -> CGImage {
    let size = CGFloat(canvas)
    let alphaInfo: CGImageAlphaInfo = fill == nil ? .premultipliedLast : .noneSkipLast
    guard let context = CGContext(
        data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue
    ) else { fatalError("cannot create \(canvas)px context") }

    if let fill {
        context.setFillColor(fill)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    } else {
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    }

    // Measure at a probe size, then scale so the line spans `glyphWidth`.
    let probe = monogramLine(fontSize: 100, font: font)
    let fontSize = 100 * CGFloat(glyphWidth) * size / lineWidth(probe)
    let line = monogramLine(fontSize: fontSize, font: font)
    let width = lineWidth(line)

    // Optically centre on cap height (M and N have no descenders).
    let baseline = (size - CTFontGetCapHeight(CTFontCreateCopyWithAttributes(font, fontSize, nil, nil))) / 2
    context.textPosition = CGPoint(x: (size - width) / 2, y: baseline)
    CTLineDraw(line, context)

    guard let image = context.makeImage() else { fatalError("cannot snapshot \(canvas)px canvas") }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "icons", code: 4, userInfo: [NSLocalizedDescriptionKey: "cannot write \(url.path)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "icons", code: 5, userInfo: [NSLocalizedDescriptionKey: "cannot finalise \(url.path)"])
    }
    print("wrote \(url.path.replacingOccurrences(of: repoRoot.path + "/", with: ""))")
}

// MARK: - Main

let font = try interFont(weight: 700)

let iosIcon = repoRoot.appendingPathComponent("MeditateAndNote/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try writePNG(render(canvas: 1024, glyphWidth: iosGlyphWidth, background: background, font: font), to: iosIcon)

let androidRes = repoRoot.appendingPathComponent("Android/app/src/main/res")
for (bucket, pixels) in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)] {
    let url = androidRes.appendingPathComponent("mipmap-\(bucket)/ic_launcher_foreground.png")
    try writePNG(render(canvas: pixels, glyphWidth: androidGlyphWidth, background: nil, font: font), to: url)
}

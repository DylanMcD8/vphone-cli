import AppKit
import ImageIO

@main
struct LosslessScreenshotTests {
    static func main() throws {
        for (width, height) in [(257, 193), (1088, 1088)] {
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    pixels[offset] = UInt8(truncatingIfNeeded: x * 37 + y * 11)
                    pixels[offset + 1] = UInt8(truncatingIfNeeded: x * 13 + y * 41)
                    pixels[offset + 2] = UInt8(truncatingIfNeeded: x ^ y)
                }
            }
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                                bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                provider: CGDataProvider(data: Data(pixels) as CFData)!,
                                decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            let data = VPhoneGraphicsDisplayCapture.pngData(for: image)!
            precondition(data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]), "Must be PNG")
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            precondition(decoded.width == width && decoded.height == height, "No window-sized resampling")
            var restored = [UInt8](repeating: 0, count: pixels.count)
            restored.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                        bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.setBlendMode(.copy)
                context.draw(decoded, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            precondition(restored == pixels, "PNG round trip must preserve every RGB pixel exactly")
            print("Lossless PNG verified: \(width)x\(height), exact pixel round trip")
        }
    }
}

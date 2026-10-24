import AppKit
import CoreGraphics
import ImageIO

/// A capa já reduzida ao tamanho em que aparece, com a média das cores dela.
/// O CGImage não muda depois de criado, então passar de uma thread para outra é seguro.
struct ProcessedArtwork: @unchecked Sendable {
    let image: CGImage
    let average: (red: Double, green: Double, blue: Double)?
}

enum ArtworkPalette {
    /// Lado maior da capa guardada, em pixels. A maior capa na ilha tem 56 pontos (112 pixels na Retina);
    /// uma capa de 3000 pixels decodificada inteira ocuparia 36 MB.
    static let maxPixelSize = 256

    /// Decodifica só o tamanho necessário e tira a média das cores. Roda fora da main thread.
    static func process(_ data: Data) -> ProcessedArtwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return ProcessedArtwork(image: image, average: averageColor(of: image))
    }

    /// A média das cores, reduzindo a capa a 8 por 8 pixels: sem CoreImage, que abriria um contexto de GPU só para isso.
    private static func averageColor(of image: CGImage) -> (red: Double, green: Double, blue: Double)? {
        let side = 8
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var red = 0, green = 0, blue = 0
        for index in stride(from: 0, to: side * side * 4, by: 4) {
            red += Int(pixels[index])
            green += Int(pixels[index + 1])
            blue += Int(pixels[index + 2])
        }
        let count = Double(side * side) * 255
        return (Double(red) / count, Double(green) / count, Double(blue) / count)
    }

    /// Cor de destaque tirada da média da capa, puxada para ficar viva sobre o preto.
    static func accent(fromAverage average: (red: Double, green: Double, blue: Double)) -> NSColor {
        let color = NSColor(deviceRed: average.red, green: average.green, blue: average.blue, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        // Capas em preto e branco não têm matiz: um cinza claro fica melhor que um vermelho inventado.
        if saturation < 0.12 { return NSColor(white: 0.88, alpha: 1) }
        return NSColor(
            deviceHue: hue,
            saturation: min(1, max(saturation, 0.45) * 1.15),
            brightness: max(brightness, 0.8),
            alpha: 1
        )
    }
}

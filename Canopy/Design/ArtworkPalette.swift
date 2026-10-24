import AppKit
import CoreImage

enum ArtworkPalette {
    /// Cor de destaque tirada da capa: a média das cores, puxada para ficar viva sobre o preto.
    static func accent(of image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]
        ), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        let average = NSColor(
            deviceRed: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
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

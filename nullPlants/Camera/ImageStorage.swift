import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

public enum ImageStorage {
    public enum Format {
        case heic(quality: CGFloat)
        case jpeg(quality: CGFloat)
    }

    public static var defaultFormat: Format = .heic(quality: 0.8)

    private enum SaveError: Error {
        case encodingFailed
        case heicNotSupported
    }

    public static func saveImage(_ image: UIImage, date: Date? = nil) throws -> String {
        // Applica watermark sempre
        let watermarkDate = date ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let watermarkText = formatter.string(from: watermarkDate)

        let watermarked = image.addingWatermark(text: watermarkText)

        let uuid = UUID().uuidString

        switch defaultFormat {
        case .heic(let quality):
            let filename = "plantphoto_\(uuid).heic"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            do {
                try save(image: watermarked, to: url, format: .heic(quality: quality))
                return filename
            } catch {
                // Fallback to jpeg with same quality
                let fallbackFilename = "plantphoto_\(uuid).jpg"
                let fallbackUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fallbackFilename)
                try save(image: watermarked, to: fallbackUrl, format: .jpeg(quality: quality))
                return fallbackFilename
            }
        case .jpeg(let quality):
            let filename = "plantphoto_\(uuid).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            try save(image: watermarked, to: url, format: .jpeg(quality: quality))
            return filename
        }
    }

    private static func save(image: UIImage, to url: URL, format: Format) throws {
        switch format {
        case .jpeg(let quality):
            guard let data = image.jpegData(compressionQuality: quality) else {
                throw SaveError.encodingFailed
            }
            try data.write(to: url)
        case .heic(let quality):
            try saveHEIC(image, to: url, quality: quality)
        }
    }

    private static func saveHEIC(_ image: UIImage, to url: URL, quality: CGFloat) throws {
        guard let cgImage = image.cgImage else {
            throw SaveError.encodingFailed
        }

        let heicUTI: CFString = (UTType.heic.identifier as CFString)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, heicUTI, 1, nil)
            ?? CGImageDestinationCreateWithURL(url as CFURL, "public.heic" as CFString, 1, nil)

        guard let dest = destination else {
            throw SaveError.heicNotSupported
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary

        CGImageDestinationAddImage(dest, cgImage, options)

        if !CGImageDestinationFinalize(dest) {
            throw SaveError.encodingFailed
        }
    }

    public static func loadImage(_ filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    public static func deleteImage(_ filename: String) {
        let fm = FileManager.default
        let url = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        if fm.fileExists(atPath: url.path) {
            do {
                try fm.removeItem(at: url)
            } catch {
                print("Errore eliminando file: \(error)")
            }
        }
    }
}

// MARK: - UIImage watermark helper
private extension UIImage {
    func addingWatermark(text: String) -> UIImage {
        let scale = self.scale
        let size = CGSize(width: self.size.width, height: self.size.height)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)

        return renderer.image { ctx in
            // Disegna l'immagine originale
            self.draw(in: CGRect(origin: .zero, size: size))

            // Calcola dimensioni relative per il testo
            let maxDimension = max(size.width, size.height)
            let margin: CGFloat = maxDimension * 0.018
            let fontSize: CGFloat = maxDimension * 0.028

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right

            let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            let roundedDescriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
            let roundedFont = UIFont(descriptor: roundedDescriptor, size: fontSize)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: roundedFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
                    shadow.shadowBlurRadius = max(1, fontSize * 0.15)
                    shadow.shadowOffset = CGSize(width: 0, height: fontSize * 0.08)
                    return shadow
                }()
            ]

            // Calcola il rect del testo
            let maxTextSize = CGSize(width: size.width * 0.8, height: CGFloat.greatestFiniteMagnitude)
            let bounding = (text as NSString).boundingRect(with: maxTextSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)

            let textSize = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
            let textOrigin = CGPoint(x: size.width - textSize.width - margin, y: size.height - textSize.height - margin)

            // Sfondo scuro arrotondato sotto il testo
            let backgroundRect = CGRect(x: textOrigin.x - margin * 0.5, y: textOrigin.y - margin * 0.5, width: textSize.width + margin, height: textSize.height + margin)
            ctx.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            let bgPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: margin)
            bgPath.fill()

            // Disegna il testo sopra lo sfondo
            (text as NSString).draw(in: CGRect(origin: textOrigin, size: textSize), withAttributes: attributes)
        }
    }
}

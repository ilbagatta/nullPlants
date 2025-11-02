import UIKit

public enum ImageStorage {
    // Salva l'immagine aggiungendo sempre un watermark con data/ora.
    // Se la data non è fornita, usa la data corrente.
    public static func saveImage(_ image: UIImage, date: Date? = nil) throws -> String {
        let filename = "plantphoto_\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)

        // Applica watermark sempre
        let watermarkDate = date ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let watermarkText = formatter.string(from: watermarkDate)

        let watermarked = image.addingWatermark(text: watermarkText)

        guard let data = watermarked.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare i dati JPEG."])
        }
        try data.write(to: url)
        return filename
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

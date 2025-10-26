import UIKit
import Foundation

func loadImage(_ filename: String) -> UIImage? {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    return UIImage(contentsOfFile: url.path)
}

func stringaDataOraDa(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    let dateString = formatter.string(from: date)
    let components = dateString.components(separatedBy: " ")
    if components.count == 2 {
        return components[0] + "\n" + components[1]
    } else {
        return dateString
    }
}

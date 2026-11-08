import Foundation
import UIKit
import ImageIO

@MainActor enum CharacterArtworkCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 32; cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    static func image(at url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1280,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: thumbnail)
        images.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
        return image
    }
}

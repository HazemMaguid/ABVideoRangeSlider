import UIKit
import AVFoundation

class ABThumbnailsManager: NSObject {

    private var thumbnailViews = [UIImageView]()
    private let thumbnailQueue = DispatchQueue(label: "com.app.thumbnailQueue", qos: .background)
    private var generator: AVAssetImageGenerator?

    func updateThumbnails(view: UIView, videoURL: URL, duration: Float64) {
        // Cancel any previous generation
        generator?.cancelAllCGImageGeneration()

        thumbnailQueue.async {
            let imageCount = self.thumbnailCount(inView: view)
            let asset = AVAsset(url: videoURL)
            let times: [NSValue] = (0..<imageCount).map { i in
                let offset = Float64(i) * (duration / Float64(imageCount))
                return NSValue(time: CMTimeMakeWithSeconds(offset, 600))
            }

            self.generator = AVAssetImageGenerator(asset: asset)
            self.generator?.appliesPreferredTrackTransform = true
            self.generator?.maximumSize = CGSize(width: 300, height: 300) // adjust as needed
            self.generator?.requestedTimeToleranceAfter = kCMTimeZero
            self.generator?.requestedTimeToleranceBefore = kCMTimeZero

            var thumbnails: [UIImage] = Array(repeating: UIImage(), count: imageCount)
            var receivedCount = 0

            self.generator?.generateCGImagesAsynchronously(forTimes: times) { requestedTime, imageRef, actualTime, result, error in
                if let imageRef = imageRef, error == nil {
                    let index = times.firstIndex(of: NSValue(time: requestedTime)) ?? 0
                    thumbnails[index] = UIImage(cgImage: imageRef)
                }

                receivedCount += 1

                // When all thumbnails are ready, update UI
                if receivedCount == imageCount {
                    DispatchQueue.main.async {
                        self.clearOldThumbnails(from: view)
                        self.addImagesToView(images: thumbnails, view: view)
                    }
                }
            }
        }
    }

    private func thumbnailCount(inView view: UIView) -> Int {
        let ratio = Double(view.frame.size.width) / Double(view.frame.size.height)
        return Int(ceil(ratio))
    }

    private func clearOldThumbnails(from view: UIView) {
        for imageView in thumbnailViews {
            imageView.removeFromSuperview()
        }
        thumbnailViews.removeAll()
    }

    private func addImagesToView(images: [UIImage], view: UIView) {
        var xPos: CGFloat = 0.0
        let height = view.frame.size.height

        for image in images {
            let remainingWidth = view.frame.size.width - xPos
            let width = min(height, remainingWidth)

            let imageView = UIImageView(image: image)
            imageView.alpha = 0
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.frame = CGRect(x: xPos, y: 0, width: width, height: height)

            thumbnailViews.append(imageView)
            view.addSubview(imageView)

            UIView.animate(withDuration: 0.2) {
                imageView.alpha = 1.0
            }

            view.sendSubview(toBack: imageView)
            xPos += height

            if xPos >= view.frame.size.width {
                break
            }
        }
    }
}

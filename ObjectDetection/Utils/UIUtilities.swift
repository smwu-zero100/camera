
import AVFoundation
import Accelerate
import Foundation
import CoreGraphics
import CoreVideo
import UIKit

/// Defines UI-related utilitiy methods for text recognition.
public class UIUtilities {
    
    // MARK: - Public
    
    public static func addCircle(
        atPoint point: CGPoint,
        to view: UIView,
        color: UIColor,
        radius: CGFloat
    ) {
        let divisor: CGFloat = 2.0
        let xCoord = point.x - radius / divisor
        let yCoord = point.y - radius / divisor
        let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
        guard circleRect.isValid() else { return }
        let circleView = UIView(frame: circleRect)
        circleView.layer.cornerRadius = radius / divisor
        circleView.alpha = Constants.circleViewAlpha
        circleView.backgroundColor = color
        view.addSubview(circleView)
    }
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        guard rectangle.isValid() else { return }
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = color
        view.addSubview(rectangleView)
    }
    
    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
        guard let points = points else { return }
        let path = UIBezierPath()
        for (index, value) in points.enumerated() {
            let point = value.cgPointValue
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            if index == points.count - 1 {
                path.close()
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        let shapeView = UIView(frame: rect)
        shapeView.alpha = Constants.shapeViewAlpha
        shapeView.layer.addSublayer(shapeLayer)
        view.addSubview(shapeView)
    }
    
    public static func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp
            || deviceOrientation
            == .unknown
        {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    
    /// Converts an image buffer to a `UIImage`.
    ///
    /// @param imageBuffer The image buffer which should be converted.
    /// @param orientation The orientation already applied to the image.
    /// @return A new `UIImage` instance.
    public static func createUIImage(
        from imageBuffer: CVImageBuffer,
        orientation: UIImage.Orientation
    ) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: Constants.originalScale, orientation: orientation)
    }
    
    /// Converts a `UIImage` to an image buffer.
    ///
    /// @param image The `UIImage` which should be converted.
    /// @return The image buffer. Callers own the returned buffer and are responsible for releasing it
    ///     when it is no longer needed. Additionally, the image orientation will not be accounted for
    ///     in the returned buffer, so callers must keep track of the orientation separately.
    public static func createImageBuffer(from image: UIImage) -> CVImageBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        var buffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil,
            &buffer)
        guard let imageBuffer = buffer else { return nil }
        
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(imageBuffer, flags)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let context = CGContext(
            data: baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: colorSpace,
            bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue
                         | CGBitmapInfo.byteOrder32Little.rawValue))
        
        if let context = context {
            let rect = CGRect.init(x: 0, y: 0, width: width, height: height)
            context.draw(cgImage, in: rect)
            CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
            return imageBuffer
        } else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
            return nil
        }
    }
    
    /// Returns a color interpolated between to other colors.
    ///
    /// - Parameters:
    ///   - fromColor: The start color of the interpolation.
    ///   - toColor: The end color of the interpolation.
    ///   - ratio: The ratio in range [0, 1] by which the colors should be interpolated. Passing 0
    ///         results in `fromColor` and passing 1 results in `toColor`, whereas passing 0.5 results
    ///         in a color that is half-way between `fromColor` and `startColor`. Values are clamped
    ///         between 0 and 1.
    /// - Returns: The interpolated color.
    private static func interpolatedColor(
        fromColor: UIColor, toColor: UIColor, ratio: CGFloat
    ) -> UIColor {
        var fromR: CGFloat = 0
        var fromG: CGFloat = 0
        var fromB: CGFloat = 0
        var fromA: CGFloat = 0
        fromColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        
        var toR: CGFloat = 0
        var toG: CGFloat = 0
        var toB: CGFloat = 0
        var toA: CGFloat = 0
        toColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        
        let clampedRatio = max(0.0, min(ratio, 1.0))
        
        let interpolatedR = fromR + (toR - fromR) * clampedRatio
        let interpolatedG = fromG + (toG - fromG) * clampedRatio
        let interpolatedB = fromB + (toB - fromB) * clampedRatio
        let interpolatedA = fromA + (toA - fromA) * clampedRatio
        
        return UIColor(
            red: interpolatedR, green: interpolatedG, blue: interpolatedB, alpha: interpolatedA)
    }
    
    /// Returns the distance between two 3D points.
    ///
    /// - Parameters:
    ///   - fromPoint: The starting point.
    ///   - endPoint: The end point.

    
    // MARK: - Private
    
    private static func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
    
    public static func rotate(image: UIImage, degree: Int) -> UIImage? {
        
        let radians = Float(degree) / (180.0 / Float.pi)
        
        var newSize = CGRect(origin: CGPoint.zero, size: image.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        image.draw(in: CGRect(x: -image.size.width/2, y: -image.size.height/2, width: image.size.width, height: image.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // 이미지 마스킹
    public static func masking(image: UIImage, rect: CGRect) -> UIImage? {
        // 회색 이미지 만들기
        let color = UIColor.gray
        let sizes = CGSize(width: rect.width, height: rect.height)

        UIGraphicsBeginImageContextWithOptions(sizes, false, 0.0)
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(origin: .zero, size: sizes))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 이미지 합성
        let ori_img = image
        let grayImage = colorImage!

        let size = CGSize(width: image.size.width, height: image.size.height)
        UIGraphicsBeginImageContext(size)

        let oriSize = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let graySize = rect
        ori_img.draw(in: oriSize)
        grayImage.draw(in: graySize)

        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

// MARK: - Constants

private enum Constants {
    static let circleViewAlpha: CGFloat = 0.7
    static let rectangleViewAlpha: CGFloat = 0.3
    static let shapeViewAlpha: CGFloat = 0.3
    static let rectangleViewCornerRadius: CGFloat = 10.0
    static let maxColorComponentValue: CGFloat = 255.0
    static let originalScale: CGFloat = 1.0
    static let bgraBytesPerPixel = 4
}

// MARK: - Extension

extension CGRect {
    /// Returns a `Bool` indicating whether the rectangle's values are valid`.
    func isValid() -> Bool {
        return
        !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0
          || origin.x < 0 || origin.y < 0)
    }
}


// MARK: - UIImage


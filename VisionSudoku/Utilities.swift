/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's reusable helper functions.
*/

import Foundation
import ARKit
import CoreML
import VideoToolbox

extension CIImage {
    
    /// Returns a pixel buffer of the image's current contents.
    func toPixelBuffer(pixelFormat: OSType) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(value: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(value: true)
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(extent.size.width),
                                         Int(extent.size.height),
                                         pixelFormat,
                                         options as CFDictionary, &buffer)
        if status == kCVReturnSuccess, let device = MTLCreateSystemDefaultDevice(), let pixelBuffer = buffer {
            let ciContext = CIContext(mtlDevice: device)
            ciContext.render(self, to: pixelBuffer)
        } else {
            print("Error: Converting CIImage to CVPixelBuffer failed.")
        }
        return buffer
    }
    
    /// Returns a copy of this image scaled to the argument size.
    func resize(to size: CGSize) -> CIImage? {
        return self.transformed(by: CGAffineTransform(scaleX: size.width / extent.size.width,
                                                      y: size.height / extent.size.height))
    }
}

extension CVPixelBuffer {
    
    /// Returns a Core Graphics image from the pixel buffer's current contents.
    func toCGImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        
        if cgImage == nil { print("Error: Converting CVPixelBuffer to CGImage failed.") }
        return cgImage
    }
}

extension MLMultiArray {
    /// Zeros out all indexes in the array except for the argument index, which is set to one.
    func setOnlyThisIndexToOne(_ index: Int) {
        if index > self.count - 1 {
            print("Error: Invalid index #\(index)")
            return
        }
        for i in 0...self.count - 1 {
            self[i] = Double(0) as NSNumber
        }
        self[index] = Double(1) as NSNumber
    }
}

/// Creates a SceneKit node with plane geometry, to the argument size, rotation, and material contents.
func createPlaneNode(size: CGSize, rotation: Float, contents: Any?) -> SCNNode {
    let plane = SCNPlane(width: size.width, height: size.height)
    plane.firstMaterial?.diffuse.contents = contents
    let planeNode = SCNNode(geometry: plane)
    
    planeNode.eulerAngles.x = rotation
    return planeNode
}


extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }

        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

            context?.translateBy(x: 0, y: self.size.height)
            context?.scaleBy(x: 1.0, y: -1.0)

            UIGraphicsPushContext(context!)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }

        return nil
    }
    
    
    func drawInconsistent () -> UIImage? {

        let renderer1 = UIGraphicsImageRenderer(size: CGSize(width: self.size.width, height: self.size.height))
        let targetImage = renderer1.image { ctx in
            let uiimage = self
            let imageRect = CGRect(x: 0, y: 0, width: uiimage.size.width, height: uiimage.size.height)
            uiimage.draw(in: imageRect)
            ctx.cgContext.setLineWidth(10)
            ctx.cgContext.setStrokeColor(UIColor.red.cgColor)
            ctx.cgContext.move(to: CGPoint(x: 0, y: 0))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width, y: self.size.height))
            ctx.cgContext.drawPath(using: .fillStroke)
            ctx.cgContext.move(to: CGPoint(x: 0, y: self.size.height))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width, y: 0))
            ctx.cgContext.drawPath(using: .fillStroke)
        }
        
        return targetImage
    }

    

    
    
    func crop () -> UIImage {
        // The shortest side
        let sideLength = min(
            self.size.width,
            self.size.height
        )

        // Determines the x,y coordinate of a centered
        // sideLength by sideLength square
        let sourceSize = self.size
        let xOffset = (sourceSize.width - sideLength) / 2.0
        let yOffset = (sourceSize.height - sideLength) / 2.0

        // The cropRect is the rect of the image to keep,
        // in this case centered
        let cropRect = CGRect(
            x: xOffset,
            y: yOffset,
            width: sideLength,
            height: sideLength
        ).integral

        return UIImage(cgImage:self.cgImage!.cropping(to: cropRect)!)
    }
    
    
    func save(withName:String) {
        if let data = self.pngData() {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let filePath = paths[0].appendingPathComponent(withName)
            do  {
                try data.write(to: filePath,options: .atomic)
            } catch let err {
                print("Saving file resulted in error: ", err)
            }
        } else {
            print("Saving file error data")
        }
    }
    
    /* func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
    */
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -origin.y, y: -origin.x,
                            width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return rotatedImage ?? self
        }

        return self
    }



}

class gridImage {
    private var dim :CGSize
    private var grid: [String]
    
    init (grid: [String],size :CGSize ) {
        self.dim = size
        self.grid = grid
    }

    func draw () -> UIImage? {
        guard grid.count==81 else {return nil}
        let mainborderwidth :CGFloat = 5
        let fontHeight = 16
        let caseWidth = Int(dim.width) / 9
        let caseHeight = Int(dim.height) / 9
        let renderer1 = UIGraphicsImageRenderer(size: CGSize(width: dim.width, height: dim.height))
        let targetImage = renderer1.image { ctx in
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(mainborderwidth)
            let rectangle = CGRect(x: 0, y: 0, width: dim.width - mainborderwidth, height: dim.height - mainborderwidth)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.addRect(rectangle)
            ctx.cgContext.drawPath(using: .fillStroke)
            for i in 1...8 {
                // Draw lines
                ctx.cgContext.setLineWidth((i % 3)==0 ? 5 : 2)
                ctx.cgContext.setStrokeColor((i % 3)==0 ? UIColor.black.cgColor : UIColor.gray.cgColor)
                ctx.cgContext.move(to: CGPoint(x: i * caseWidth, y: Int(mainborderwidth)))
                ctx.cgContext.addLine(to: CGPoint(x: caseWidth * i, y: Int(dim.height-mainborderwidth)))
                ctx.cgContext.drawPath(using: .fillStroke)
                ctx.cgContext.move(to: CGPoint(x: Int(mainborderwidth), y: i * caseHeight))
                ctx.cgContext.addLine(to: CGPoint(x: Int(dim.width-mainborderwidth), y: i * caseHeight))
                ctx.cgContext.drawPath(using: .fillStroke)
            }
            for i in 0...80 {
                let targetCell = CGRect (x: (i%9)*caseWidth, y: Int(i/9)*caseHeight + caseHeight/2 - fontHeight/2, width: caseWidth, height: caseHeight)
                let paragraphStyle = NSMutableParagraphStyle()
                let string = grid[i]
                let fontDim :CGFloat = CGFloat((string.count > 1) ? fontHeight / 2 : fontHeight)
                paragraphStyle.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontDim),
                    .paragraphStyle: paragraphStyle
                ]
                let attributedString = NSAttributedString(string: string, attributes: attrs)
                attributedString.draw(with: targetCell, options: .usesLineFragmentOrigin, context:nil)
            }
        }
        return targetImage
    }

}




class HourGlass {
    var size :CGSize
    
    init (size:CGSize) {
        self.size = size
    }
    
    
    func circle(center :CGPoint,radius:CGFloat, startAngle: CGFloat, endAngle: CGFloat) -> UIImage {
        let renderer1 = UIGraphicsImageRenderer(size: CGSize(width: self.size.width, height: self.size.height))
        let targetImage = renderer1.image { ctx in
            let stripHudLength = radius
            var stripHudOrigin = 2.0 //self.size.width / 10
            ctx.cgContext.setLineWidth(8)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.move(to: CGPoint(x: stripHudOrigin, y: stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudOrigin, y: stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudLength, y: stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: self.size.width - stripHudOrigin, y: stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudOrigin, y: stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudLength, y: stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: stripHudOrigin, y: self.size.height - stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudOrigin, y: self.size.height - stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudLength, y: self.size.height - stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: self.size.width - stripHudOrigin, y: self.size.height - stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudOrigin, y: self.size.height - stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudLength, y: self.size.width - stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)
            
            stripHudOrigin = 3.0
            ctx.cgContext.setLineWidth(6)
            ctx.cgContext.setStrokeColor(UIColor.green.cgColor)
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.move(to: CGPoint(x: stripHudOrigin, y: stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudOrigin, y: stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudLength, y: stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: self.size.width - stripHudOrigin, y: stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudOrigin, y: stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudLength, y: stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: stripHudOrigin, y: self.size.height - stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudOrigin, y: self.size.height - stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: stripHudLength, y: self.size.height - stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            ctx.cgContext.move(to: CGPoint(x: self.size.width - stripHudOrigin, y: self.size.height - stripHudLength))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudOrigin, y: self.size.height - stripHudOrigin))
            ctx.cgContext.addLine(to: CGPoint(x: self.size.width - stripHudLength, y: self.size.width - stripHudOrigin))
            ctx.cgContext.drawPath(using: .fillStroke)

            
            
            ctx.cgContext.setStrokeColor(UIColor(red: 0, green: 100, blue: 0, alpha: 1).cgColor)
            ctx.cgContext.setLineWidth(10)
            ctx.cgContext.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            ctx.cgContext.drawPath(using: .fillStroke)

        }
        
        return targetImage
    }
    

}



class ImageSaver: NSObject {
    // use:
    // let imageSaver = ImageSaver()
    // imageSaver.writeToPhotoAlbum(image: inputImage)
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveError), nil)
    }

    @objc func saveError(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    }
}




extension CIImage {
    func contrast (intensity:CGFloat) -> CGImage? {
        let parameters = ["inputContrast":intensity]
        let outputImage = self.applyingFilter("CIColorControls", parameters: parameters)
        let context = CIContext (options: nil)
        let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        return cgImage
    }
    
    
}



extension CGImage {
    func gray () -> CGImage {

        // Create image rectangle with current image width/height
        let imageRect:CGRect = CGRect(x:0, y:0, width:self.width, height: self.height)

        // Grayscale color space
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = self.width
        let height = self.height

        // Create bitmap content with current image size and grayscale colorspace
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        // Draw image into current context, with specified rectangle
        // using previously defined context (with grayscale colorspace)
        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(self, in: imageRect)
        let imageRef = context!.makeImage()

        return imageRef!
    }
    
    
    func PixelColor(pos: CGPoint) -> UIColor {

        let pixelData = self.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let pixelInfo: Int = ((Int(self.width) * Int(pos.y)) + Int(pos.x)) * 4

        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    enum borderType: CaseIterable {
    case top
    case bottom
    case left
    case right
    }
    
    func borderSize () -> [borderType:Int] {
        var result :[borderType:Int] = [.top:0,.right:0,.left:0,.bottom:0]
        var sizeToScan = 0
        var orgX, orgY :Int
        var kX,kY :Int
        var whitestripcompleted,blackstripcompleted,endstripcompleted :Bool
        var nwhitestrip,nblackstrip :Int
        
        
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let bytesPerRow = width * 4

        guard let imageContext = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return result }
        
        imageContext.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
        
        for iFrom in CGImage.borderType.allCases {
            switch iFrom {
            case .top:
                orgX = Int (self.width / 2)
                orgY = 0
                kX = 0
                kY = +1
                sizeToScan = Int (self.height / 5 )
            case .bottom:
                orgX = Int (self.width / 2)
                orgY = self.height - 1
                kX = 0
                kY = -1
                sizeToScan = Int (self.height / 5 )
            case .left:
                orgX = 0
                orgY = Int (self.height / 2)
                kX = +1
                kY = 0
                sizeToScan = Int (self.width / 5 )
            case .right:
                orgX = self.width - 1
                orgY = Int (self.height / 2)
                kX = -1
                kY = 0
                sizeToScan = Int (self.width / 5 )
            }
            whitestripcompleted = false
            blackstripcompleted = false
            endstripcompleted = false
            nwhitestrip = 0
            nblackstrip = 0
            var i = 0
            while i < sizeToScan && !endstripcompleted {
                let index = (orgY + i * kY) * width + orgX + i * kX
                let pixel = pixels[index]
                let r = pixel.red //data[pixelInfo]
                let g = pixel.green //data[pixelInfo+1]
                let b = pixel.blue //data[pixelInfo+2]
                let intensity = (r>150 || g>150 || b>150) ? true : false

                if !whitestripcompleted && intensity {
                    nwhitestrip += 1
                } else if (!whitestripcompleted && !intensity) {
                    whitestripcompleted = true
                }
                
                if !blackstripcompleted && whitestripcompleted && !intensity {
                    nblackstrip += 1
                } else if (!blackstripcompleted && whitestripcompleted && intensity) {
                    blackstripcompleted = true
                }
                
                if whitestripcompleted && blackstripcompleted && intensity {
                    endstripcompleted = true
                }
                i += 1
            }
            
            if i < sizeToScan {
                result[iFrom] = nblackstrip + nwhitestrip
            }

        }
        imageData.deallocate()

        return result
    }

}

class imageToProcessClass {
    
    var cgImage :CGImage?
    var bufferImage :CVImageBuffer?
    var border :[CGImage.borderType:Int] = [.top:0,.right:0,.left:0,.bottom:0]
    var surface :Int = 0
    var isPortrait :Bool = false
    
    init(imageBuffer:CVImageBuffer?, isPortrait:Bool) {
        guard let imageBuffer = imageBuffer,
              let image = imageBuffer.toCGImage() else { return }
        //
        self.bufferImage = imageBuffer
        self.isPortrait = isPortrait
        self.cgImage = image
        self.border = image.gray().borderSize()
        self.surface = cgImage!.width * cgImage!.height
    }
}


public struct Pixel {
    public var value: UInt32
    
    public var red: UInt8 {
        get {
            return UInt8(value & 0xFF)
        } set {
            value = UInt32(newValue) | (value & 0xFFFFFF00)
        }
    }
    
    public var green: UInt8 {
        get {
            return UInt8((value >> 8) & 0xFF)
        } set {
            value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF)
        }
    }
    
    public var blue: UInt8 {
        get {
            return UInt8((value >> 16) & 0xFF)
        } set {
            value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF)
        }
    }
    
    public var alpha: UInt8 {
        get {
            return UInt8((value >> 24) & 0xFF)
        } set {
            value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF)
        }
    }
}

//
//  EditedImage.swift
//  VisionSudoku
//
//  Created by Laurent Lefevre on 24/10/2021.
//

import Foundation
import ARKit
import CoreML

/// - Tag: AlteredImage
class EditedImage {

    let referenceImage: ARReferenceImage
    
    /// A handle to the anchor ARKit assigned the tracked image.
    private(set) var anchor: ARImageAnchor?
    
    /// A SceneKit node that animates images of varying style.
    private let visualizationNode: VisualizationNode
        
    /// A timer that effects a grace period before checking
    ///  for a new rectangular shape in the user's environment.
    //private var failedTrackingTimeout: Timer?
    
    /// The timeout in seconds after which the `imageTrackingLost` delegate is called.
    //private var timeout: TimeInterval = 1.0
        
    /// The input parameters to the Core ML model.
    var originalCIImage : CIImage?
    var uiImageTreated : UIImage?
    var isPortrait :Bool
    /// A delegate to tell when image tracking fails.
    weak var delegate: EditedImageDelegate?
    
    init?(_ image: CIImage, referenceImage: ARReferenceImage,isPortrait: Bool) {
        self.referenceImage = referenceImage
        visualizationNode = VisualizationNode(referenceImage.physicalSize)
        self.originalCIImage = image
        self.isPortrait = isPortrait
    }
    
    deinit {
        visualizationNode.removeAllAnimations()
        visualizationNode.removeFromParentNode()
    }
    
    /// Displays the altered image using the anchor and node provided by ARKit.
    /// - Tag: AddVisualizationNode
    func add(_ anchor: ARAnchor, node: SCNNode) {
        if let imageAnchor = anchor as? ARImageAnchor, imageAnchor.referenceImage == referenceImage {
            self.anchor = imageAnchor
           
            // Add the node that displays the altered image to the node graph.
            node.addChildNode(visualizationNode)

            self.createAlteredImage()
        }
    }
    
    /**
     If an image the app was tracking is no longer tracked for a given amount of time, invalidate
     the current image tracking session. This, in turn, enables Vision to start looking for a new
     rectangular shape in the camera feed.
     - Tag: AnchorWasUpdated
     */
    func update(_ anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor, self.anchor == anchor {
            self.anchor = imageAnchor
            // Reset the timeout if the app is still tracking an image.
            if imageAnchor.isTracked {
                //resetImageTrackingTimeout()
            }
        }
    }
    
    
    /// Alters the image's appearance by applying the "StyleTransfer" Core ML model to it.
    /// - Tag: CreateAlteredImage
    func createAlteredImage() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.uiImageTreated = self.drawFrame(withDigit: nil, resultGrid: nil)
            self.imageAlteringComplete((self.uiImageTreated?.toCVPixelBuffer())!)
        }
    }
    
    
    func refreshAlteredImage(withDigit :[Int:GridElement]?,resultGrid :[String]?) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.uiImageTreated = self.drawFrame(withDigit: withDigit, resultGrid: resultGrid)
            self.imageAlteringComplete((self.uiImageTreated?.toCVPixelBuffer())!)
        }
    }
    
    
    func saveToAlbum () {
        let imageSaver = ImageSaver()
        imageSaver.writeToPhotoAlbum(image: self.uiImageTreated!)
    }
    
    
    /// - Tag: DisplayAlteredImage
    func imageAlteringComplete(_ createdImage: CVPixelBuffer) {
        visualizationNode.display(createdImage)
    }
    
    func imageAlteringComplete(_ createdImage: CIImage) {
        visualizationNode.display(createdImage)
    }
    

    /// If altering the image failed, notify delegate the
    ///  to stop tracking this image.
    func imageAlteringFailed(_ errorDescription: String) {
        print("Error: Altering image failed - \(errorDescription).")
        self.delegate?.alteredImageLostTracking(self)
    }
    
    
    func drawFrame(withDigit :[Int:GridElement]?,resultGrid :[String]?) -> UIImage? {
        guard let originalCIImage = originalCIImage else {
            return nil
        }
        let uiimage = UIImage (ciImage: originalCIImage)
        let borderWidth :CGFloat = 5
        let showResult = (resultGrid==nil) ? false : (resultGrid?.count==81)
    
        UIGraphicsBeginImageContext(uiimage.size)
        let imageRect = CGRect(x: 0, y: 0, width: uiimage.size.width, height: uiimage.size.height)
        uiimage.draw(in: imageRect)
        
        let context = UIGraphicsGetCurrentContext()
        let borderRect = imageRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        
        context?.setStrokeColor(UIColor.green.cgColor)
        context?.setLineWidth(borderWidth)
        context?.stroke(borderRect)
        
        if let digit = withDigit {
            let caseWidth = Int(uiimage.size.width) / 9
            let caseHeight = Int(uiimage.size.height) / 9
            for digit in digit {
                let forIndex = digit.key
                let x = (forIndex % 9) * caseWidth
                let y = Int (forIndex/9) * caseHeight
                let rectangle = CGRect(x: x, y: y, width: caseWidth, height: caseHeight)
                if digit.value.value.count==1 {
                    context?.setFillColor(UIColor.clear.cgColor)
                    context?.setStrokeColor(UIColor(red: 0, green: 0.5, blue: 0, alpha: 1).cgColor)
                    context?.setLineWidth(5)

                    context?.addEllipse(in: rectangle)
                    context?.drawPath(using: .fillStroke)
                } else if showResult && resultGrid![digit.key].count==1 {
                    let rotateby :CGFloat = self.isPortrait ? -.pi/2 : 0
                    digitImage(digit: resultGrid![digit.key], fontDim: CGFloat (caseHeight / 2), rectangle: rectangle.size, rotateby: rotateby).draw(at: CGPoint(x: x, y: y))
                        /*
                        let paragraphStyle = NSMutableParagraphStyle()
                        let fontDim :CGFloat = CGFloat (caseHeight / 2)
                        paragraphStyle.alignment = .center
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: fontDim),
                            .strokeColor: UIColor(red: 0, green: 0.5, blue: 0, alpha: 1).cgColor,
                            .paragraphStyle: paragraphStyle
                        ]
                        let attributedString = NSAttributedString(string: resultGrid![digit.key], attributes: attrs)
                        
                        attributedString.draw(with: rectangle, options: .usesLineFragmentOrigin, context: nil)
                         */
                }
            }
            if let result = resultGrid, result[0] == "-1" {
                context?.setLineWidth(10)
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.move(to: CGPoint(x: 0, y: 0))
                context?.addLine(to: CGPoint(x: uiimage.size.width, y: uiimage.size.height))
                context?.drawPath(using: .fillStroke)
                context?.move(to: CGPoint(x: 0, y: uiimage.size.height))
                context?.addLine(to: CGPoint(x: uiimage.size.width, y: 0))
                context?.drawPath(using: .fillStroke)

            }
        }
        
        let borderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return borderedImage

    }
    
    func digitImage (digit: String, fontDim:CGFloat, rectangle:CGSize, rotateby:CGFloat) -> UIImage {
        let fontsize :CGFloat = 48
        let imgsize = CGRect(x: 0, y: 0, width: rectangle.width, height: rectangle.height)
        UIGraphicsBeginImageContext(imgsize.size)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size:imgsize.size)
        (digit as NSString).draw(in: rect, withAttributes: [
            NSAttributedString.Key.font: UIFont(name: "Helvetica", size: fontsize)!,
            NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0.5, blue: 0, alpha: 1).cgColor,
            NSAttributedString.Key.backgroundColor:UIColor.clear.cgColor,
            NSAttributedString.Key.paragraphStyle: titleParagraphStyle
            ])
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        //img?.rotate(by: .pi/2, flip: false)
        return img!.rotate(radians: rotateby)
     }

}


/**
 Tells a delegate when image tracking failed.
  In this case, the delegate is the view controller.
 */
protocol EditedImageDelegate: AnyObject {
    func alteredImageLostTracking(_ alteredImage: EditedImage)
}

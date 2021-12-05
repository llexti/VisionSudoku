/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SceneKit node that fades between two images.
*/

import Foundation
import SceneKit
import ARKit

class VisualizationNode: SCNNode {

    private let currentImage: SCNNode

    init(_ size: CGSize) {
        currentImage = createPlaneNode(size: size, rotation: -.pi / 2, contents: UIColor.clear)
        super.init()
        addChildNode(currentImage)
    }
    
    func display(_ alteredImage: CVPixelBuffer) {
        currentImage.geometry?.firstMaterial?.diffuse.contents = alteredImage.toCGImage()
        currentImage.opacity = 1.0
    }

    func display(_ alteredImage: CIImage) {
        currentImage.geometry?.firstMaterial?.diffuse.contents = alteredImage
        currentImage.opacity = 1.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

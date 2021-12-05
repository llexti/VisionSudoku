//
//  ViewController.swift
//  VisionSudoku
//
//  Created by Laurent Lefevre on 23/10/2021.
// based on: https://developer.apple.com/documentation/arkit/content_anchors/tracking_and_altering_images
//

import UIKit
import ARKit
import Foundation
import SceneKit
import UIKit


class GridElement {
    var id :Int
    var accuracy :Int
    var value :String
    var image :UIImage?

    init (id:Int) {
        self.id = id
        self.accuracy = 0
        self.value = ""
        self.image = nil
    }
    
    func found (value:String) {
        if (self.value==value /* && value.count>0 */) {
            self.accuracy += 1
        } else if (self.accuracy<3 /* && value.count>0 */) {
            self.accuracy = 0
            self.value = value
        }
    }
    
}

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var hudImage: UIImageView!
    
    static var instance: ViewController?
    private var casenumber = -1
    private var grid :[Int:GridElement] = [:]
    private var nIterationTotal = 5
    private var processStarted :Bool = false
    private var digitArray :[String] = [""," ","1","2","3","4","5","6","7","8","9"]
    private var resultGrid :[String]?
    /// An object that detects rectangular shapes in the user's environment.
    let rectangleDetector = RectangleDetector()
    var alteredImage: EditedImage?
    private var treatedImage: imageToProcessClass?
    private var imageToBeProcessed :[imageToProcessClass] = []
    private var imageToBeProcessedIndex :Int = -1
    private var isBusy = false
    private var updateTimer :Timer?
    private var updateHud :Timer?
    private var hud :HourGlass?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rectangleDetector.delegate = self
        sceneView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ViewController.instance = self
        
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.runImageTrackingSession(with: [], runOptions: [.removeExistingAnchors, .resetTracking])
        
        self.hud = HourGlass (size: self.hudImage.frame.size)
        
        self.initHud(updateInterval: 0)
    }


    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destinationVC = segue.destination
        if (destinationVC.isKind(of: VisionDetailsCollectionViewController.self)) {
            let vc = destinationVC as! VisionDetailsCollectionViewController
            vc.grid = self.grid
        } // End of switch(segue.identifier ?? "")
        if (destinationVC.isKind(of: SolveViewController.self)) {
            let vc = destinationVC as! SolveViewController
            vc.initVC(self.grid)
        } // End of switch(segue.identifier ?? "")
    }
    
    
    @IBAction func solve(_ sender: Any) {
        guard !self.processStarted  else  {return}
        var gridTemp :[String] = []
        
        for i in 0...80 {
            gridTemp.append(grid[i]!.value)
        }

        let solver = solver ()
        solver.delegate = self
        let result = solver.population(grid: gridTemp)
        if  solver.validity(grid: result) {
            self.resultGrid = solver.possibilities(grid: gridTemp)
            self.alteredImage?.refreshAlteredImage(withDigit: self.grid, resultGrid: self.resultGrid)
        } else {
            if let alteredImage = self.alteredImage {
                alteredImage.refreshAlteredImage(withDigit: self.grid, resultGrid: ["-1"])
            }
        }
    }
    
    @IBAction func saveToAlbum(_ sender: Any) {
        self.alteredImage?.saveToAlbum()
    }
    
    @IBAction func startScan(_ sender: Any) {
        self.searchForNewImageToTrack()
     }
    

    func initAnalyse (updateInterval:TimeInterval) {
        self.isBusy = false
        // Timer Analysis
        self.updateTimer = Timer.scheduledTimer(withTimeInterval:updateInterval , repeats: true) { [weak self] _ in
            guard !self!.isBusy else { return }
            self?.isBusy = true
            self?.analyse()
        }
    }

    func initHud (updateInterval:TimeInterval) {
        if updateInterval==0 {
            self.endHud()
        } else {
            // Timer Head-up Display - every second
            self.updateHud = Timer.scheduledTimer(withTimeInterval:updateInterval , repeats: true) { [weak self] _ in
                DispatchQueue.main.async { [self] in
                    let nImages = self!.imageToBeProcessed.count
                    let processPct = (CGFloat (nImages) / CGFloat (self!.nIterationTotal) + CGFloat(self!.casenumber + 1 + self!.imageToBeProcessedIndex * 81 + 81) / CGFloat (self!.nIterationTotal*81)) / 2.0
                    self!.alteredImage?.refreshAlteredImage(withDigit: self!.grid, resultGrid: self!.resultGrid)
                    let toImage = self!.hud?.circle(center: CGPoint(x: self!.hudImage.frame.width/2, y: self!.hudImage.frame.height/2), radius: 50, startAngle: 0, endAngle: processPct * .pi * 2)
                    self?.hudImage.image = toImage
                }
            }
        }
    }
    
    func endHud () {
        self.updateHud?.invalidate()
        self.updateHud = nil
        let toImage = self.hud?.circle(center: CGPoint(x: self.hudImage.frame.width/2, y: self.hudImage.frame.height/2), radius: 50, startAngle: 0, endAngle: 0)
        self.hudImage.image = toImage
    }

    
    
    func analyse () {
        repeat {
            self.casenumber += 1
        } while self.casenumber<81 && self.accurate(digit: self.casenumber)
        if self.casenumber<81 {
            self.digitRequest (forIndex: self.casenumber)
        } else {
            if self.initImageToProcess(begin: false) {
                self.digitRequest (forIndex: self.casenumber)
            }
        }
    }


    func imagesAccuracy () -> Bool {
        for iGrid in self.grid {
            if iGrid.value.accuracy<3 {
                return false
            }
        }
        return true
    }
    

    func initImageToProcess (begin:Bool) -> Bool {
        var proceed :Bool = true
        self.imageToBeProcessedIndex = begin ? 0 : (self.imageToBeProcessedIndex + 1)
        if (self.imagesAccuracy()){
            self.casenumber = 80
            self.imageToBeProcessedIndex = self.imageToBeProcessed.count
        }
        if (self.imageToBeProcessedIndex < self.imageToBeProcessed.count) {
            self.casenumber = -1
            self.treatedImage = self.imageToBeProcessed[self.imageToBeProcessedIndex]
        } else {
            self.imageToBeProcessed.removeAll()
            self.imageToBeProcessedIndex = -1
            self.processStarted = false
            proceed = false
            self.updateTimer?.invalidate()
            self.updateTimer = nil
            self.endHud()
            self.solve(self)
        }
        return proceed
    }
    
    
    
    func searchForNewImageToTrack() {
        // Init the grid
        self.grid.removeAll()
        for i in 0...80 {
            grid[i] = GridElement(id: i)
        }
        self.casenumber = -1
        self.imageToBeProcessed.removeAll()
        self.resultGrid = nil

        alteredImage?.delegate = nil
        alteredImage = nil
        
        self.runImageTrackingSession(with: [], runOptions: [.removeExistingAnchors, .resetTracking])
        self.rectangleDetector.detection(hold: false)
        self.processStarted = true
        self.initHud(updateInterval: 1)

    }

    
    
    /// - Tag: ImageTrackingSession
    private func runImageTrackingSession(with trackingImages: Set<ARReferenceImage>,
                                         runOptions: ARSession.RunOptions = [.removeExistingAnchors]) {
        let configuration = ARImageTrackingConfiguration()
        configuration.maximumNumberOfTrackedImages = 1
        configuration.trackingImages = trackingImages
        sceneView.session.run(configuration, options: runOptions)
    }
        
}

//
// 1ere méthode: on selectionne un rectange qu'on découpe en 81 cases
//
extension ViewController {
    func accurate (digit:Int) -> Bool {
        guard let element = self.grid[digit], element.accuracy>2 else { return false }
        
        return true
    }
    
    func digitRequest (forIndex:Int) {
        // Get the CGImage on which to perform requests.
        guard self.treatedImage != nil,
              let border = self.treatedImage?.border,
              let cgimage = self.treatedImage?.cgImage,
              let bufferimage = self.treatedImage?.bufferImage else {
                self.isBusy = false
                return
            }
        //
        let isPortrait :Bool = self.treatedImage?.isPortrait ?? false
        let correctionTop = border[.top] ?? 0
        let correctionBottom = border[.bottom] ?? 0
        let correctionLeft = border[.left] ?? 0
        let correctionRight = border[.right] ?? 0
        //
        let casecorrection = 3
        let caseWidth = (cgimage.width - correctionLeft - correctionRight) / 9
        let caseHeight = (cgimage.height - correctionTop - correctionBottom) / 9
        let x = (forIndex % 9) * caseWidth + correctionLeft
        let y = Int (forIndex/9) * caseHeight + correctionTop
        let dim = CGRect(x: x + casecorrection, y: y + casecorrection, width: caseWidth - casecorrection, height: caseHeight - casecorrection)
        
        let imageContrastCG = CIImage(cvPixelBuffer: bufferimage, options: [ : ]).contrast(intensity: 3.0)
        if let imageCropCGWR = imageContrastCG?.cropping(to: dim)?.gray() {
            let imageCropCG = isPortrait ? UIImage(cgImage: imageCropCGWR).rotate(radians: .pi/2).toCVPixelBuffer()?.toCGImage() : imageCropCGWR
            self.grid[self.casenumber]?.image = UIImage(cgImage: imageCropCG!)
            let requestHandler = VNImageRequestHandler(cgImage: imageCropCG!, options: [ : ])

            // Create a new request to recognize text.
            let request = VNRecognizeTextRequest(completionHandler: self.recognizeTextHandler)
            request.recognitionLevel = .fast
            do {
                try requestHandler.perform([request])
            } catch {
                print("Unable to perform the requests: \(error).")
            }
        } else {
            self.isBusy = false
        }
    }

    
    
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            self.isBusy = false
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        if let candidate = recognizedStrings.first /*, candidate.count==1*/  {
            var candidateCorrected = candidate
            if (candidateCorrected=="I") {
                candidateCorrected = "1"
            }
            if (digitArray.contains (candidateCorrected)) {
                self.grid[self.casenumber]?.found(value:candidateCorrected)
            }
        } else {
            self.grid[self.casenumber]?.found(value:"")
        }
        
        self.isBusy = false

    }
    

}



extension ViewController: ARSCNViewDelegate {
    
    /// - Tag: ImageWasRecognized
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        alteredImage?.add(anchor, node: node)
    }

    /// - Tag: DidUpdateAnchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        alteredImage?.update(anchor)
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        if arError.code == .invalidReferenceImage {
            print("Error: The detected rectangle cannot be tracked.")
            searchForNewImageToTrack()
            return
        }
        
        let errorWithInfo = arError as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Use `compactMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that just occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.searchForNewImageToTrack()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

}


extension ViewController: RectangleDetectorDelegate {
    /// Called when the app recognized a rectangular shape in the user's envirnment.
    /// - Tag: CreateReferenceImage
    func rectangleFound(rectangleContent: CIImage) {
        //
        DispatchQueue.main.async {
            // kCVPixelFormatType_32BGRA
            guard let referenceImagePixelBuffer = rectangleContent.toPixelBuffer(pixelFormat:kCVPixelFormatType_32BGRA) else {
                print("Error: Could not convert rectangle content into an ARReferenceImage.")
                return
            }
            // Verify that the size is not too small
            
            let isPortrait = self.view.window?.windowScene?.interfaceOrientation.isPortrait ?? false
            
            var bAdd = true
            let imageToProcess = imageToProcessClass (imageBuffer: referenceImagePixelBuffer, isPortrait: isPortrait)
            self.imageToBeProcessed.forEach { imageRecorded in
                bAdd = bAdd && (100 * (imageRecorded.surface - imageToProcess.surface)<40 * imageRecorded.surface)
            }
            if self.processStarted && bAdd {
                self.imageToBeProcessed.append(imageToProcess)
            }
            /*
             Set a default physical width of 50 centimeters for the new reference image.
             While this estimate is likely incorrect, that's fine for the purpose of the
             app. The content will still appear in the correct location and at the correct
             scale relative to the image that's being tracked.
             */
            
            let possibleReferenceImage = ARReferenceImage(referenceImagePixelBuffer, orientation: .up, physicalWidth: CGFloat(0.5))
            
            possibleReferenceImage.validate { [weak self] (error) in
                if let error = error {
                    print("Reference image validation failed: \(error.localizedDescription)")
                    return
                }

                // Try tracking the image that lies within the rectangle which the app just detected.
                guard let newAlteredImage = EditedImage(rectangleContent, referenceImage: possibleReferenceImage, isPortrait: isPortrait) else { return }
                newAlteredImage.delegate = self
                self?.alteredImage = newAlteredImage
                self?.runImageTrackingSession(with:[newAlteredImage.referenceImage])
            }
            //
            self.infoLabel.text = self.processStarted ? "Capturing pictures" : "Tap the screen once targeted"
            // Starts analyse
            if (self.imageToBeProcessed.count == self.nIterationTotal && self.processStarted) {
                self.processStarted = false
                self.rectangleDetector.detection(hold: true)
                if self.initImageToProcess(begin: true) {
                    self.initAnalyse(updateInterval: 0.05)
                }
            }
        }
    }
}



/// Enables the app to create a new image from any rectangular shapes that may exist in the user's environment.
extension ViewController: EditedImageDelegate {
    func alteredImageLostTracking(_ alteredImage: EditedImage) {
        searchForNewImageToTrack()
    }
}


extension ViewController :solverDelegate {
    func processGrid(cells: [String]) {
    }
    
}


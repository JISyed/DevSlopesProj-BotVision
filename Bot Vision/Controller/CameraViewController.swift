//
//  ViewController.swift
//  Bot Vision
//
//  Created by Jibran Syed on 10/27/17.
//  Copyright © 2017 Jishenaz. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState
{
    case off
    case on
}

class CameraViewController: UIViewController 
{
    @IBOutlet weak var imgCapturedImage: RoundedShadowImageView!
    @IBOutlet weak var btnFlash: RoundedShadowButton!
    @IBOutlet weak var lblIdentification: UILabel!
    @IBOutlet weak var lblConfidence: UILabel!
    @IBOutlet weak var viewCamera: UIView!
    @IBOutlet weak var viewItemInfo: RoundedShadowView!
    @IBOutlet weak var widthCapturedImage: NSLayoutConstraint!
    @IBOutlet weak var heightCapturedImage: NSLayoutConstraint!
    @IBOutlet weak var spinnerThumbnail: UIActivityIndicatorView!
    
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var photoData: Data?
    var flashControlState: FlashState = .off
    
    var speechSynthesizer = AVSpeechSynthesizer()
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let screenRect = UIScreen.main.bounds
        let imageWidth = self.widthCapturedImage.constant
        self.heightCapturedImage.constant = (imageWidth * screenRect.height) / screenRect.width
        self.spinnerThumbnail.isHidden = true
        
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) 
    {
        super.viewDidAppear(animated)
        
        // Setup the live camera preview layer (allows camera vision to show up on the screen)
        self.videoPreviewLayer.frame = self.viewCamera.bounds
        
        // Setup speech synthesizer
        self.speechSynthesizer.delegate = self
    }
    
    
    override func viewWillAppear(_ animated: Bool) 
    {
        super.viewWillAppear(animated)
        
        
        // Setup tap gesture recognizer for taking a photo
        let tap = UITapGestureRecognizer(target: self, action: #selector(CameraViewController.onCameraViewTapped))
        tap.numberOfTapsRequired = 1
        self.viewCamera.addGestureRecognizer(tap)
        
        
        
        // Instantiate our capture session and other camera stuff
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)    // Capture the whole screen (videos do this, photos don't)
        do
        {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input)
            {
                captureSession.addInput(input)
            }
            
            self.cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(self.cameraOutput)
            {
                captureSession.addOutput(self.cameraOutput!)
                
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
                self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                self.videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                
                self.viewCamera.layer.addSublayer(self.videoPreviewLayer!)
                self.captureSession.startRunning()
            }
        }
        catch
        {
            debugPrint(error)
        }
        
        
    }
    
    
    
    @objc
    func onCameraViewTapped()
    {
        self.viewCamera.isUserInteractionEnabled = false    // Stop camera tapping trigger
        self.spinnerThumbnail.isHidden = false
        self.spinnerThumbnail.startAnimating()
        
        
        let captureSettings = AVCapturePhotoSettings()
        let previewPixelType = captureSettings.availablePreviewPhotoPixelFormatTypes.first! // Returns first processed iOS photo
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160]
        captureSettings.previewPhotoFormat = previewFormat  // settings.embeddedThumbnailPhotoFormat
        
        if self.flashControlState == .off
        {
            captureSettings.flashMode = .off
        }
        else
        {
            captureSettings.flashMode = .on
        }
        
        self.cameraOutput.capturePhoto(with: captureSettings, delegate: self)
    }
    
    
    // CoreML here...
    func resultsMethod(request: VNRequest, error: Error?)
    {
        guard let results = request.results as? [VNClassificationObservation] else {return}
        
        for classification in results
        {
            if classification.confidence < 0.5
            {
                let unknownObjectMessage = "I'm not sure what this is. Please try again."
                self.lblIdentification.text = unknownObjectMessage
                self.synthesizeSpeech(fromString: unknownObjectMessage) // Speak it!
                self.lblConfidence.text = ""
                break
            }
            else    // There is at least 50% confidence in the classification
            {
                let identification = classification.identifier // The name of the object classified
                let confidence = Int(classification.confidence * 100)
                self.lblIdentification.text = identification
                self.lblConfidence.text = "CONFIDENCE: \(confidence)%"
                
                // Speak it
                let knownObjectMessage = "This looks like a \(identification), and I'm \(confidence) percent sure."
                self.synthesizeSpeech(fromString: knownObjectMessage)
                
                break
            }
        }
    }
    
    
    
    func synthesizeSpeech(fromString string: String)
    {
        let speechUtterance = AVSpeechUtterance(string: string)
        self.speechSynthesizer.speak(speechUtterance)
    }
    
    
    
    @IBAction func onFlashBtnPressed(_ sender: Any) 
    {
        if self.flashControlState == .off
        {
            self.flashControlState = .on
            self.btnFlash.setTitle("FLASH ON", for: .normal)
        }
        else // .on
        {
            self.flashControlState = .off
            self.btnFlash.setTitle("FLASH OFF", for: .normal)
        }
    }
    
    
}



// Camera stuff
extension CameraViewController: AVCapturePhotoCaptureDelegate
{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) 
    {
        if let captureError = error
        {
            debugPrint(captureError)
        }
        else
        {
            self.photoData = photo.fileDataRepresentation()
            
            
            // CoreML here...
            do
            {
                let model = try VNCoreMLModel(for: SqueezeNet().model)                          // Get a model (like a brain)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)   // Request for using our brain to make a thought
                let handler = VNImageRequestHandler(data: self.photoData!)                      // Handler for taking the data and comparing it to our "thought"
                try handler.perform([request])                                                  // Actually compares input to model and makes prediction
            }
            catch
            {
                debugPrint(error)
            }
            
            
            
            let photoImage = UIImage(data: self.photoData!)
            
            // Set the captured photo into our litle preview window
            self.imgCapturedImage.image = photoImage
        }
    }
}




// Speech synthesis stuff
extension CameraViewController: AVSpeechSynthesizerDelegate
{
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) 
    {
        self.spinnerThumbnail.stopAnimating()
        self.spinnerThumbnail.isHidden = true
        self.viewCamera.isUserInteractionEnabled = true
    }
}




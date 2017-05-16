/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Photo capture delegate.
*/

import AVFoundation
import Photos

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
	private(set) var requestedPhotoSettings: AVCapturePhotoSettings
	
	private let willCapturePhotoAnimation: () -> ()
	
	private let completed: (PhotoCaptureDelegate) -> ()
	
	var photoData: Data? = nil
    var displayImage: UIImage?
	
	init(with requestedPhotoSettings: AVCapturePhotoSettings, willCapturePhotoAnimation: @escaping () -> (), completed: @escaping (PhotoCaptureDelegate) -> ()) {
		self.requestedPhotoSettings = requestedPhotoSettings
		self.willCapturePhotoAnimation = willCapturePhotoAnimation
		self.completed = completed
	}
	
	private func didFinish() {
		completed(self)
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("resolvedSettings.previewDimensions = \(resolvedSettings.previewDimensions)")
		willCapturePhotoAnimation()
	}
	
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
		if let photoSampleBuffer = photoSampleBuffer {
            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            if previewPhotoSampleBuffer != nil {
                if let pixelBuffer = CMSampleBufferGetImageBuffer(previewPhotoSampleBuffer!) {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let context = CIContext()
                    
                    let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
                    print("capture imageRect: \(imageRect)")
                    print("UIScreen.main.scale: \(UIScreen.main.scale)")
                    
                    if let image = context.createCGImage(ciImage, from: imageRect) {
//                        self.displayImage = UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
                        self.displayImage = UIImage(cgImage: image, scale: 1.0, orientation: .right)
                    }
                }
            }
        } else {
			print("Error capturing photo: \(error)")
			return
		}
	}
	
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		if let error = error {
			print("Error capturing photo: \(error)")
			didFinish()
			return
		}
		
		guard let photoData = photoData else {
			print("No photo data resource")
			didFinish()
			return
		}
		
		PHPhotoLibrary.requestAuthorization { [unowned self] status in
			if status == .authorized {
				PHPhotoLibrary.shared().performChanges({ [unowned self] in
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .photo, data: photoData, options: nil)
										
                    }, completionHandler: { [unowned self] success, error in
						if let error = error {
							print("Error occurered while saving photo to photo library: \(error)")
						}
						self.didFinish()
					}
				)
			}
			else {
				self.didFinish()
			}
		}
	}
}

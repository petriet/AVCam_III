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
	
	private var photoData: Data? = nil
	
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
		willCapturePhotoAnimation()
	}
	
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
		if let photoSampleBuffer = photoSampleBuffer {
            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
		}
		else {
			print("Error capturing photo: \(error)")
			return
		}
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {

	}
	
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplay photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		if let _ = error {
			print("Error processing live photo companion movie: \(error)")
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

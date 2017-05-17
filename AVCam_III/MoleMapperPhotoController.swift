/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos

// MARK: MoleMapperControllerDelegate protocol

@objc public protocol MoleMapperPhotoControllerDelegate {
    func moleMapperPhotoControllerDidTakePictures(_ jpegData: Data?, displayPhoto: UIImage?, lensPosition: Float)
    func moleMapperPhotoControllerDidCancel(_ controller: MoleMapperPhotoController)
}

@objc protocol MyTestProtocol {
    func someFunction(_ someData: Data?, aPhoto: UIImage?)
}

@objc public class MoleMapperPhotoController: UIViewController, UIGestureRecognizerDelegate {
    
    static private let queueName = "edu.ohsu.molemapper.photoQ"
    
    private var acceptViewer: AcceptViewController?
    private var acceptingPhotoCaptureDelegateObjectID: Int64 = 0
    private var currentCameraPosition: AVCaptureDevicePosition = AVCaptureDevicePosition.unspecified
    private var inProgressPhotoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
    private var isSessionRunning = false
    private var lastLensPosition: Float = -1.0
    private var lensPositionNotificationsCount = 0
    private let photoOutput = AVCapturePhotoOutput()
    private var previewView: PreviewView!
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: queueName, attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
    private var setupResult: SessionSetupResult = .success
    private var takePhotoFlag = false
    private let videoDeviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)!
    private var videoDeviceInput: AVCaptureDeviceInput!
    
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: Properties
    
    var controllerDelegate: MoleMapperPhotoControllerDelegate!
    var showControls = false
    var letUserApprovePhoto = true
    
    // MARK: View Controller Life Cycle
    
    convenience init(withDelegate delegate: MoleMapperPhotoControllerDelegate) {
        self.init(nibName: nil, bundle: nil)
        controllerDelegate = delegate
    }
    
    override public func loadView() {
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.backgroundColor = .white
        previewView = PreviewView()
        previewView.backgroundColor = .black

        var offset = CGFloat(0.0)
        if let nav = self.navigationController {
            offset += nav.navigationBar.bounds.height
        }
        offset += UIApplication.shared.statusBarFrame.size.height

        var adjustedFrame = self.view.frame
        adjustedFrame.origin.y += offset
        adjustedFrame.size.height -= offset
        
        if showControls {
            let controlToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
            controlToolbar.sizeToFit()
            controlToolbar.tintColor = .white
            controlToolbar.barTintColor = .black
            adjustedFrame.size.height -= controlToolbar.bounds.height
            controlToolbar.backgroundColor = .black
            let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain,
                                               target: controllerDelegate,
                                               action: #selector(MoleMapperPhotoControllerDelegate.moleMapperPhotoControllerDidCancel))

            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let rotateCameraButton = UIBarButtonItem(title: "Flip", style: .plain,
                                               target: self,
                                               action: #selector(self.changeCamera))

            controlToolbar.setItems([cancelButton, spacer, rotateCameraButton], animated: false)
            controlToolbar.frame.origin.y = UIScreen.main.bounds.height - controlToolbar.frame.height
            self.view.addSubview(controlToolbar)
        }
        self.previewView.frame = adjustedFrame
        self.view.addSubview(self.previewView!)     // adding the previewView layer as a sublayer crashes the app

        let gestureRecognizer = UITapGestureRecognizer(target: self,
                                                       action: #selector(MoleMapperPhotoController.focusAndExposeTap(gestureRecognizer:)))
        gestureRecognizer.delegate = self
        self.view.addGestureRecognizer(gestureRecognizer)
    }
    
    override public func viewDidLoad() {
		super.viewDidLoad()

        
		// Set up the video preview view.
		previewView.session = session
		
		/*
			Check video authorization status. Video access is required and audio
			access is optional. If audio access is denied, audio is not recorded
			during movie recording.
		*/
		switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
            case .authorized:
				// The user has previously granted access to the camera.
				break
			
			case .notDetermined:
				/*
					The user has not yet been presented with the option to grant
					video access. We suspend the session queue to delay session
					setup until the access request has completed.
				
					Note that audio access will be implicitly requested when we
					create an AVCaptureDeviceInput for audio during session setup.
				*/
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})
			
			default:
				// The user has previously denied access.
				setupResult = .notAuthorized
		}
		
		/*
			Setup the capture session.
			In general it is not safe to mutate an AVCaptureSession or any of its
			inputs, outputs, or connections from multiple threads at the same time.
		
			Why not do all of this on the main queue?
			Because AVCaptureSession.startRunning() is a blocking call which can
			take a long time. We dispatch session setup to the sessionQueue so
			that the main queue isn't blocked, which keeps the UI responsive.
		*/
		sessionQueue.async { [unowned self] in
			self.configureSession()
		}
	}
	
	override public func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
        
		sessionQueue.async { [unowned self] in
            switch self.setupResult {
                case .success:
				    // Only setup observers and start the session running if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                    do {
                        if let device = self.videoDeviceInput.device {
                            if device.hasTorch {
                                try device.lockForConfiguration()
                                if device.isExposureModeSupported(.continuousAutoExposure) {
                                    device.exposureMode = .continuousAutoExposure
                                }
                                device.torchMode = .on
                                device.unlockForConfiguration()
                            }
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
				
                case .notAuthorized:
                    DispatchQueue.main.async { [unowned self] in
                        let message = NSLocalizedString("MoleMapper doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                        let alertController = UIAlertController(title: "MoleMapper", message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                        }))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
				
                case .configurationFailed:
                    DispatchQueue.main.async { [unowned self] in
                        let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                        let alertController = UIAlertController(title: "MoleMapper", message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
			}
		}
	}
	
	override public func viewWillDisappear(_ animated: Bool) {
		sessionQueue.async { [unowned self] in
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				self.removeObservers()
			}
		}
		
		super.viewWillDisappear(animated)
	}
	
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .portrait
	}
    
    // MARK: Delegate Handlers
	
    func onUsePhoto() {
        if self.acceptViewer != nil {
            self.acceptViewer?.dismiss(animated: true, completion: {self.acceptViewer = nil})
        }
        self.sessionQueue.async { [unowned self] in
            if let photoCaptureDelegate = self.inProgressPhotoCaptureDelegates[self.acceptingPhotoCaptureDelegateObjectID] {
                self.controllerDelegate.moleMapperPhotoControllerDidTakePictures(photoCaptureDelegate.photoData,
                                                                             displayPhoto: photoCaptureDelegate.displayImage,
                                                                             lensPosition: self.lastLensPosition)
            }
            self.inProgressPhotoCaptureDelegates[self.acceptingPhotoCaptureDelegateObjectID] = nil
        }
    }
    
    func onRetake() {
        if self.acceptViewer != nil {
            self.sessionQueue.async { [unowned self] in
                self.inProgressPhotoCaptureDelegates[self.acceptingPhotoCaptureDelegateObjectID] = nil
            }
            self.acceptViewer?.dismiss(animated: true, completion: {self.acceptViewer = nil})
            // Dismissing modal VC returns to us and causes a viewWillAppear call which
            // resets the camera session and observers
        }
    }
    
    
	// MARK: Session Management
	
	
	// Call this on the session queue.
	private func configureSession() {
		if setupResult != .success {
			return
		}
		
		session.beginConfiguration()
		
		/*
			We do not create an AVCaptureMovieFileOutput when setting up the session because the
			AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
		*/
		session.sessionPreset = AVCaptureSessionPresetPhoto
		
		// Add video input.
		do {
			var defaultVideoDevice: AVCaptureDevice?
			
			// Choose the back wide-angle camera if available
			if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
				// If the back dual camera is not available, default to the back wide angle camera.
				defaultVideoDevice = backCameraDevice
                currentCameraPosition = .back
			}
			else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
				// In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
				defaultVideoDevice = frontCameraDevice
                currentCameraPosition = .front
			}
			
			let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
			
			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput
                self.previewView.videoPreviewLayer.connection.videoOrientation = .portrait
			}
			else {
				print("Could not add video device input to the session")
				setupResult = .configurationFailed
				session.commitConfiguration()
				return
			}
		}
		catch {
			print("Could not create video device input: \(error)")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		// Add photo output.
		if session.canAddOutput(photoOutput)
		{
			session.addOutput(photoOutput)
			photoOutput.isHighResolutionCaptureEnabled = true
		}
		else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
        
		
		session.commitConfiguration()
	}
			
	// MARK: Device Configuration
	
    func changeCamera() {
		
		sessionQueue.async { [unowned self] in
			let currentVideoDevice = self.videoDeviceInput.device
			let currentPosition = currentVideoDevice!.position
			
			let preferredPosition: AVCaptureDevicePosition
			let preferredDeviceType: AVCaptureDeviceType
			
			switch currentPosition {
				case .unspecified, .front:
					preferredPosition = .back
					preferredDeviceType = .builtInWideAngleCamera
				
				case .back:
					preferredPosition = .front
					preferredDeviceType = .builtInWideAngleCamera
			}
			
			let devices = self.videoDeviceDiscoverySession.devices!
			var newVideoDevice: AVCaptureDevice? = nil
			
			// First, look for a device with both the preferred position and device type. Otherwise, look for a device with only the preferred position.
			if let device = devices.filter({ $0.position == preferredPosition && $0.deviceType == preferredDeviceType }).first {
				newVideoDevice = device
			}
			else if let device = devices.filter({ $0.position == preferredPosition }).first {
				newVideoDevice = device
			}

            if let videoDevice = newVideoDevice {
                self.currentCameraPosition = preferredPosition
                do {
					let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
					
					self.session.beginConfiguration()
					
					// Remove the existing device input first, since using the front and back camera simultaneously is not supported.
					self.session.removeInput(self.videoDeviceInput)
					
					if self.session.canAddInput(videoDeviceInput) {
						NotificationCenter.default.removeObserver(self, name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: currentVideoDevice!)
						
						NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: videoDeviceInput.device)
                        
                        currentVideoDevice!.removeObserver(self, forKeyPath: "adjustingFocus")
                        currentVideoDevice!.removeObserver(self, forKeyPath: "lensPosition")
                        videoDeviceInput.device.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)
                        videoDeviceInput.device.addObserver(self, forKeyPath: "lensPosition", options: .new, context: nil)
						
						self.session.addInput(videoDeviceInput)
						self.videoDeviceInput = videoDeviceInput
					}
					else {
						self.session.addInput(self.videoDeviceInput);
					}
					
					self.session.commitConfiguration()
				}
				catch {
					print("Error occured while creating video device input: \(error)")
				}
			}
			
		}
	}
	
	@objc private func focusAndExposeTap(gestureRecognizer: UITapGestureRecognizer) {
        self.lastLensPosition = -1.0
        self.lensPositionNotificationsCount = 0
        if currentCameraPosition == .back {
            let devicePoint = self.previewView.videoPreviewLayer.captureDevicePointOfInterest(for: gestureRecognizer.location(in: gestureRecognizer.view))
            focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
            takePhotoFlag = true
        } else {
            capturePhoto()
        }
	}
	
	private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
		sessionQueue.async { [unowned self] in
			if let device = self.videoDeviceInput.device {
				do {
					try device.lockForConfiguration()
					
					/*
						Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
						Call set(Focus/Exposure)Mode() to apply the new point of interest.
					*/
					if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
						device.focusPointOfInterest = devicePoint
						device.focusMode = focusMode
					}
					
					if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
						device.exposurePointOfInterest = devicePoint
						device.exposureMode = .continuousAutoExposure
					}
					
					device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
					device.unlockForConfiguration()
				}
				catch {
					print("Could not lock device for configuration: \(error)")
				}
			}
		}
	}
	
	// MARK: Capturing Photos

	func capturePhoto() {
		/*
			Retrieve the video preview layer's video orientation on the main queue before
			entering the session queue. We do this to ensure UI elements are accessed on
			the main thread and session configuration is done on the session queue.
		*/
//		let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation        // should always be .portrait
		
		sessionQueue.async {
			// Update the photo output's connection to match the video orientation of the video preview layer.
			if let photoOutputConnection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo) {
//                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
				photoOutputConnection.videoOrientation = .portrait
			}
			
			// Capture a JPEG photo with flash set to auto and high resolution photo enabled.
			let photoSettings = AVCapturePhotoSettings()
			//photoSettings.flashMode = .auto
			photoSettings.isHighResolutionPhotoEnabled = true
			if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                /*
                    This is whacked. No matter what you tell iOS, it wants to treat all preview images as landscape. So we tell it
                    the landscape numbers that will give us the portrait resizing we want (i.e. flip width and height)
                 */
				photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!,
				                                    kCVPixelBufferWidthKey as String : UIScreen.main.bounds.height,
				                                    kCVPixelBufferHeightKey as String : UIScreen.main.bounds.width
                ]
			}

            // Use a separate object for the photo capture delegate to isolate each capture life cycle.
			let photoCaptureDelegate = PhotoCaptureDelegate(with: photoSettings, willCapturePhotoAnimation: {
                    // Pushed until after the capture is complete
				}, completed: { [unowned self] photoCaptureDelegate in
                    // Animation should occur _after_ the focus + snapshot
                    DispatchQueue.main.async { [unowned self] in
                        self.previewView.videoPreviewLayer.opacity = 0
                        UIView.animate(withDuration: 0.25) { [unowned self] in
                            self.previewView.videoPreviewLayer.opacity = 1
                        }
                    }
                    if self.letUserApprovePhoto {
                        DispatchQueue.main.async { [unowned self] in
                            self.acceptingPhotoCaptureDelegateObjectID = photoCaptureDelegate.requestedPhotoSettings.uniqueID
                            self.acceptViewer = AcceptViewController(with: self, image: photoCaptureDelegate.displayImage!)
                            self.show(self.acceptViewer!, sender: self)
                        }
                    } else {
                        self.sessionQueue.async { [unowned self] in
                            self.controllerDelegate.moleMapperPhotoControllerDidTakePictures(photoCaptureDelegate.photoData,
                                                                                     displayPhoto: photoCaptureDelegate.displayImage,
                                                                                     lensPosition: self.lastLensPosition)
                            self.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = nil
                        }
                    }
				}
			)
			
			/*
				The Photo Output keeps a weak reference to the photo capture delegate so
				we store it in an array to maintain a strong reference to this object
				until the capture is completed.
			*/
			self.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = photoCaptureDelegate
			self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
		}
	}
		
	// MARK: KVO and Notifications
	
	private var sessionRunningObserveContext = 0
	
	private func addObservers() {
		session.addObserver(self, forKeyPath: "running", options: .new, context: &sessionRunningObserveContext)
        if self.videoDeviceInput != nil {
            self.videoDeviceInput.device.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)
            self.videoDeviceInput.device.addObserver(self, forKeyPath: "lensPosition", options: .new, context: nil)
        }
		
		NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: videoDeviceInput.device)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"), object: session)
		
		/*
			A session can only run when the app is full screen. It will be interrupted
			in a multi-app layout, introduced in iOS 9, see also the documentation of
			AVCaptureSessionInterruptionReason. Add observers to handle these session
			interruptions and show a preview is paused message. See the documentation
			of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
		*/
		NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: Notification.Name("AVCaptureSessionWasInterruptedNotification"), object: session)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: Notification.Name("AVCaptureSessionInterruptionEndedNotification"), object: session)
	}
	
	private func removeObservers() {
		NotificationCenter.default.removeObserver(self)
		
		session.removeObserver(self, forKeyPath: "running", context: &sessionRunningObserveContext)
        
        if self.videoDeviceInput != nil {
            self.videoDeviceInput.device.removeObserver(self, forKeyPath: "adjustingFocus")
            self.videoDeviceInput.device.removeObserver(self, forKeyPath: "lensPosition")
        }
    }
	
	override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if context == &sessionRunningObserveContext {
			let newValue = change?[.newKey] as AnyObject?
            
            if keyPath == "running" {
                guard let isSessionRunning = newValue?.boolValue else { return }
            }
        } else if keyPath == "adjustingFocus" {
/*
             Note that when traditional contrast detect auto-focus is in use, the AVCaptureDevice adjustingFocus property flips to YES when a focus 
             is underway, and flips back to NO when it is done. When phase detect autofocus is in use, the adjustingFocus property does not flip to YES, 
             as the phase detect method tends to focus more frequently, but in small, sometimes imperceptible amounts. You can observe the 
             AVCaptureDevice lensPosition property to see lens movements that are driven by phase detect AF.

*/
            if let focusingState = change?[.newKey] as! Bool? {
                if !focusingState {
                    if takePhotoFlag {
                        if lensPositionNotificationsCount > 3 {     // Seem to get YES..NO...YES...lensPos lensPos...NO sequence
                            takePhotoFlag = false
                            capturePhoto()
                        }
                    }
                }
            }
        } else if keyPath == "lensPosition" {
            if let lensPosition = change?[.newKey] as! Float? {
                lastLensPosition = lensPosition
                lensPositionNotificationsCount += 1
            }
        } else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
		}
	}
	
	func subjectAreaDidChange(notification: NSNotification) {
		let devicePoint = CGPoint(x: 0.5, y: 0.5)
		focus(with: .autoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
	}
	
	func sessionRuntimeError(notification: NSNotification) {
		guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
			return
		}
		
        let error = AVError(_nsError: errorValue)
		print("Capture session runtime error: \(error)")
		
		/*
			Automatically try to restart the session running if media services were
			reset and the last start running succeeded. Otherwise, enable the user
			to try to resume the session running.
		*/
		if error.code == .mediaServicesWereReset {
			sessionQueue.async { [unowned self] in
				if self.isSessionRunning {
					self.session.startRunning()
					self.isSessionRunning = self.session.isRunning
				}
			}
		}
	}
	
	func sessionWasInterrupted(notification: NSNotification) {
		if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) {
			print("Capture session was interrupted with reason \(reason)")
						
			if reason == AVCaptureSessionInterruptionReason.audioDeviceInUseByAnotherClient || reason == AVCaptureSessionInterruptionReason.videoDeviceInUseByAnotherClient {
                // TODO
            }
		}
	}
	
	func sessionInterruptionEnded(notification: NSNotification) {
		print("Capture session interruption ended")
		
	}
}


/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {
	// MARK: View Controller Life Cycle
    var controllerDelegate: NavigationControllerEx!
    var previewView: PreviewView!
    
    convenience init(_ delegate: NavigationControllerEx) {
        self.init(nibName: nil, bundle: nil)
        controllerDelegate = delegate
    }
    
    override func loadView() {
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.backgroundColor = .black
        previewView = PreviewView()
        self.view.layer.addSublayer(previewView.layer)
        self.previewView.frame = self.view.frame

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CameraViewController.focusAndExposeTap(gestureRecognizer:)))
        gestureRecognizer.delegate = self
        self.view.addGestureRecognizer(gestureRecognizer)
    }
	
    override func viewDidLoad() {
		super.viewDidLoad()

        //self.view.backgroundColor = .green
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Prev", style: .plain,
                                                                target: controllerDelegate,
                                                                action: #selector(NavigationControllerEx.onPrev))
        
        self.navigationItem.title = "Tap to Snap"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done,
                                                                 target: controllerDelegate,
                                                                 action: #selector(NavigationControllerEx.onNext))
        
        
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
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		sessionQueue.async {
			switch self.setupResult {
                case .success:
				    // Only setup observers and start the session running if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
				
                case .notAuthorized:
                    DispatchQueue.main.async { [unowned self] in
                        let message = NSLocalizedString("AVCam doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                        }))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
				
                case .configurationFailed:
                    DispatchQueue.main.async { [unowned self] in
                        let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		sessionQueue.async { [unowned self] in
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				self.removeObservers()
			}
		}
		
		super.viewWillDisappear(animated)
	}
	
    override var shouldAutorotate: Bool {
		// Disable autorotation of the interface when recording is in progress.
		if let movieFileOutput = movieFileOutput {
			return !movieFileOutput.isRecording
		}
		return true
	}
	
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
			let deviceOrientation = UIDevice.current.orientation
			guard let newVideoOrientation = deviceOrientation.videoOrientation, deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
				return
			}
			
			videoPreviewLayerConnection.videoOrientation = newVideoOrientation
		}
	}

	// MARK: Session Management
	
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	
	private let session = AVCaptureSession()
	
	private var isSessionRunning = false
	
	private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
	
	private var setupResult: SessionSetupResult = .success
	
	var videoDeviceInput: AVCaptureDeviceInput!
	
	
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
			}
			else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
				// In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
				defaultVideoDevice = frontCameraDevice
			}
			
			let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
			
			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput
                videoDeviceInput.device.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)

				
				DispatchQueue.main.async {
					/*
						Why are we dispatching this to the main queue?
						Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
						can only be manipulated on the main thread.
						Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
						on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
					
						Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
						handled by CameraViewController.viewWillTransition(to:with:).
					*/
					let statusBarOrientation = UIApplication.shared.statusBarOrientation
					var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
					if statusBarOrientation != .unknown {
						if let videoOrientation = statusBarOrientation.videoOrientation {
							initialVideoOrientation = videoOrientation
						}
					}
					
					self.previewView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation
				}
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
		
		// Add audio input.
		do {
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
			let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
			
			if session.canAddInput(audioDeviceInput) {
				session.addInput(audioDeviceInput)
			}
			else {
				print("Could not add audio device input to the session")
			}
		}
		catch {
			print("Could not create audio device input: \(error)")
		}
		
		// Add photo output.
		if session.canAddOutput(photoOutput)
		{
			session.addOutput(photoOutput)
			
			photoOutput.isHighResolutionCaptureEnabled = true
			photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
			livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
		}
		else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		session.commitConfiguration()
	}
	
	@IBAction private func resumeInterruptedSession(_ resumeButton: UIButton)
	{
		sessionQueue.async { [unowned self] in
			/*
				The session might fail to start running, e.g., if a phone or FaceTime call is still
				using audio or video. A failure to start the session running will be communicated via
				a session runtime error notification. To avoid repeatedly failing to start the session
				running, we only try to restart the session running in the session runtime error handler
				if we aren't trying to resume the session running.
			*/
			self.session.startRunning()
			self.isSessionRunning = self.session.isRunning
			if !self.session.isRunning {
				DispatchQueue.main.async { [unowned self] in
					let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
					let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
					let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
					alertController.addAction(cancelAction)
					self.present(alertController, animated: true, completion: nil)
				}
			}
		}
	}
	
	private enum CaptureMode: Int {
		case photo = 0
		case movie = 1
	}

//	@IBOutlet private weak var captureModeControl: UISegmentedControl!
	
	@IBAction private func toggleCaptureMode(_ captureModeControl: UISegmentedControl) {
		if captureModeControl.selectedSegmentIndex == CaptureMode.photo.rawValue {
//			recordButton.isEnabled = false
			
			sessionQueue.async { [unowned self] in
				/*
					Remove the AVCaptureMovieFileOutput from the session because movie recording is
					not supported with AVCaptureSessionPresetPhoto. Additionally, Live Photo
					capture is not supported when an AVCaptureMovieFileOutput is connected to the session.
				*/
				self.session.beginConfiguration()
				self.session.removeOutput(self.movieFileOutput)
				self.session.sessionPreset = AVCaptureSessionPresetPhoto
				self.session.commitConfiguration()
				
				self.movieFileOutput = nil
				
				if self.photoOutput.isLivePhotoCaptureSupported {
					self.photoOutput.isLivePhotoCaptureEnabled = true
					
				}
			}
		}
		else if captureModeControl.selectedSegmentIndex == CaptureMode.movie.rawValue
		{
//			livePhotoModeButton.isHidden = true
			
			sessionQueue.async { [unowned self] in
 				let movieFileOutput = AVCaptureMovieFileOutput()
				
				if self.session.canAddOutput(movieFileOutput) {
					self.session.beginConfiguration()
					self.session.addOutput(movieFileOutput)
					self.session.sessionPreset = AVCaptureSessionPresetHigh
					if let connection = movieFileOutput.connection(withMediaType: AVMediaTypeVideo) {
						if connection.isVideoStabilizationSupported {
							connection.preferredVideoStabilizationMode = .auto
						}
					}
					self.session.commitConfiguration()
					
					self.movieFileOutput = movieFileOutput
					
				}
			}
		}
	}
	
	// MARK: Device Configuration
	
//	@IBOutlet private weak var cameraButton: UIButton!
	
//	@IBOutlet private weak var cameraUnavailableLabel: UILabel!
	
	private let videoDeviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDuoCamera], mediaType: AVMediaTypeVideo, position: .unspecified)!
	
	@IBAction private func changeCamera(_ cameraButton: UIButton) {
//		cameraButton.isEnabled = false
//		recordButton.isEnabled = false
//		photoButton.isEnabled = false
//		livePhotoModeButton.isEnabled = false
//		captureModeControl.isEnabled = false
		
		sessionQueue.async { [unowned self] in
			let currentVideoDevice = self.videoDeviceInput.device
			let currentPosition = currentVideoDevice!.position
			
			let preferredPosition: AVCaptureDevicePosition
			let preferredDeviceType: AVCaptureDeviceType
			
			switch currentPosition {
				case .unspecified, .front:
					preferredPosition = .back
					preferredDeviceType = .builtInDuoCamera
				
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
                do {
					let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
					
					self.session.beginConfiguration()
					
					// Remove the existing device input first, since using the front and back camera simultaneously is not supported.
					self.session.removeInput(self.videoDeviceInput)
					
					if self.session.canAddInput(videoDeviceInput) {
						NotificationCenter.default.removeObserver(self, name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: currentVideoDevice!)
						
						NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: videoDeviceInput.device)
                        
                        print("adding adjustingFocus observation to videoDeviceInput")
                        currentVideoDevice!.removeObserver(self, forKeyPath: "adjustingFocus")
                        videoDeviceInput.device.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)
						
						self.session.addInput(videoDeviceInput)
						self.videoDeviceInput = videoDeviceInput
					}
					else {
						self.session.addInput(self.videoDeviceInput);
					}
					
					if let connection = self.movieFileOutput?.connection(withMediaType: AVMediaTypeVideo) {
						if connection.isVideoStabilizationSupported {
							connection.preferredVideoStabilizationMode = .auto
						}
					}
					
					/*
						Set Live Photo capture enabled if it is supported. When changing cameras, the
						`isLivePhotoCaptureEnabled` property of the AVCapturePhotoOutput gets set to NO when
						a video device is disconnected from the session. After the new video device is
						added to the session, re-enable Live Photo capture on the AVCapturePhotoOutput if it is supported.
					*/
					self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported;
					
					self.session.commitConfiguration()
				}
				catch {
					print("Error occured while creating video device input: \(error)")
				}
			}
			
		}
	}
	
	@objc private func focusAndExposeTap(gestureRecognizer: UITapGestureRecognizer) {
		let devicePoint = self.previewView.videoPreviewLayer.captureDevicePointOfInterest(for: gestureRecognizer.location(in: gestureRecognizer.view))
		focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
	}
	
	private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
		sessionQueue.async { [unowned self] in
			if let device = self.videoDeviceInput.device {
				do {
                    print("focusing")
					try device.lockForConfiguration()
					
					/*
						Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
						Call set(Focus/Exposure)Mode() to apply the new point of interest.
					*/
					if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
						device.focusPointOfInterest = devicePoint
						device.focusMode = focusMode
					}
					
					if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
						device.exposurePointOfInterest = devicePoint
						device.exposureMode = exposureMode
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

	private let photoOutput = AVCapturePhotoOutput()
	
	private var inProgressPhotoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
	
//	@IBOutlet private weak var photoButton: UIButton!
	
	func capturePhoto() {
		/*
			Retrieve the video preview layer's video orientation on the main queue before
			entering the session queue. We do this to ensure UI elements are accessed on
			the main thread and session configuration is done on the session queue.
		*/
		let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation
		
		sessionQueue.async {
			// Update the photo output's connection to match the video orientation of the video preview layer.
			if let photoOutputConnection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo) {
				photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
			}
			
			// Capture a JPEG photo with flash set to auto and high resolution photo enabled.
			let photoSettings = AVCapturePhotoSettings()
			photoSettings.flashMode = .auto
			photoSettings.isHighResolutionPhotoEnabled = true
			if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
				photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
			}
			if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported { // Live Photo capture is not supported in movie mode.
				let livePhotoMovieFileName = NSUUID().uuidString
				let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
				photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
			}
			
			// Use a separate object for the photo capture delegate to isolate each capture life cycle.
			let photoCaptureDelegate = PhotoCaptureDelegate(with: photoSettings, willCapturePhotoAnimation: {
					DispatchQueue.main.async { [unowned self] in
						self.previewView.videoPreviewLayer.opacity = 0
						UIView.animate(withDuration: 0.25) { [unowned self] in
							self.previewView.videoPreviewLayer.opacity = 1
						}
					}
				}, capturingLivePhoto: { capturing in
					/*
						Because Live Photo captures can overlap, we need to keep track of the
						number of in progress Live Photo captures to ensure that the
						Live Photo label stays visible during these captures.
					*/
					self.sessionQueue.async { [unowned self] in
						if capturing {
							self.inProgressLivePhotoCapturesCount += 1
						}
						else {
							self.inProgressLivePhotoCapturesCount -= 1
						}
						
						let inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount
						}

				}, completed: { [unowned self] photoCaptureDelegate in
					// When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
					self.sessionQueue.async { [unowned self] in
						self.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = nil
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
	
	private enum LivePhotoMode {
		case on
		case off
	}
	
	private var livePhotoMode: LivePhotoMode = .off
	
//	@IBOutlet private weak var livePhotoModeButton: UIButton!
	
	@IBAction private func toggleLivePhotoMode(_ livePhotoModeButton: UIButton) {
		sessionQueue.async { [unowned self] in
			self.livePhotoMode = (self.livePhotoMode == .on) ? .off : .on
			let livePhotoMode = self.livePhotoMode
		}
	}
	
	private var inProgressLivePhotoCapturesCount = 0
	
//	@IBOutlet var capturingLivePhotoLabel: UILabel!
	
	// MARK: Recording Movies
	
	private var movieFileOutput: AVCaptureMovieFileOutput? = nil
	
	private var backgroundRecordingID: UIBackgroundTaskIdentifier? = nil
	
//	@IBOutlet private weak var recordButton: UIButton!
	
//	@IBOutlet private weak var resumeButton: UIButton!
	
	@IBAction private func toggleMovieRecording(_ recordButton: UIButton) {
		guard let movieFileOutput = self.movieFileOutput else {
			return
		}
		
		/*
			Disable the Camera button until recording finishes, and disable
			the Record button until recording starts or finishes.
		
			See the AVCaptureFileOutputRecordingDelegate methods.
		*/
		
		/*
			Retrieve the video preview layer's video orientation on the main queue
			before entering the session queue. We do this to ensure UI elements are
			accessed on the main thread and session configuration is done on the session queue.
		*/
		let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation
		
		sessionQueue.async { [unowned self] in
			if !movieFileOutput.isRecording {
				if UIDevice.current.isMultitaskingSupported {
					/*
						Setup background task.
						This is needed because the `capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)`
						callback is not received until AVCam returns to the foreground unless you request background execution time.
						This also ensures that there will be time to write the file to the photo library when AVCam is backgrounded.
						To conclude this background execution, endBackgroundTask(_:) is called in
						`capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)` after the recorded file has been saved.
					*/
					self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
				}
				
				// Update the orientation on the movie file output video connection before starting recording.
				let movieFileOutputConnection = self.movieFileOutput?.connection(withMediaType: AVMediaTypeVideo)
				movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation
				
				// Start recording to a temporary file.
				let outputFileName = NSUUID().uuidString
				let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				movieFileOutput.startRecording(toOutputFileURL: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
			}
			else {
				movieFileOutput.stopRecording()
			}
		}
	}
	
	func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
		// Enable the Record button to let the user stop the recording.
	}
	
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
		/*
			Note that currentBackgroundRecordingID is used to end the background task
			associated with this recording. This allows a new recording to be started,
			associated with a new UIBackgroundTaskIdentifier, once the movie file output's
			`isRecording` property is back to false — which happens sometime after this method
			returns.
		
			Note: Since we use a unique file path for each recording, a new recording will
			not overwrite a recording currently being saved.
		*/
		func cleanup() {
			let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                }
                catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
			
			if let currentBackgroundRecordingID = backgroundRecordingID {
				backgroundRecordingID = UIBackgroundTaskInvalid
				
				if currentBackgroundRecordingID != UIBackgroundTaskInvalid {
					UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
				}
			}
		}
		
		var success = true
		
		if error != nil {
			print("Movie file finishing error: \(error)")
			success = (((error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
		}
		
		if success {
			// Check authorization status.
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					// Save the movie file to the photo library and cleanup.
					PHPhotoLibrary.shared().performChanges({
							let options = PHAssetResourceCreationOptions()
							options.shouldMoveFile = true
							let creationRequest = PHAssetCreationRequest.forAsset()
							creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
						}, completionHandler: { success, error in
							if !success {
								print("Could not save movie to photo library: \(error)")
							}
							cleanup()
						}
					)
				}
				else {
					cleanup()
				}
			}
		}
		else {
			cleanup()
		}
		
		// Enable the Camera and Record buttons to let the user switch camera and start another recording.
	}
	
	// MARK: KVO and Notifications
	
	private var sessionRunningObserveContext = 0
	
	private func addObservers() {
		session.addObserver(self, forKeyPath: "running", options: .new, context: &sessionRunningObserveContext)
		
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
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("value \(keyPath) observed")
		if context == &sessionRunningObserveContext {
			let newValue = change?[.newKey] as AnyObject?
            
            if keyPath == "running" {
                print("observed running")
                guard let isSessionRunning = newValue?.boolValue else { return }
//                let isLivePhotoCaptureSupported = photoOutput.isLivePhotoCaptureSupported
//                let isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureEnabled
			
            }
        } else if keyPath == "adjustingFocus" {
            if let something = change?[.newKey] as! Bool? {
                if something {
                    print("focusing")
                } else {
                    print("focused")
                }
            }
//            print("observed adjusting focus: \(something)")
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
		/*
			In some scenarios we want to enable the user to resume the session running.
			For example, if music playback is initiated via control center while
			using AVCam, then the user can let AVCam resume
			the session running, which will stop music playback. Note that stopping
			music playback in control center will not automatically resume the session
			running. Also note that it is not always possible to resume, see `resumeInterruptedSession(_:)`.
		*/
		if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) {
			print("Capture session was interrupted with reason \(reason)")
			
			var showResumeButton = false
			
			if reason == AVCaptureSessionInterruptionReason.audioDeviceInUseByAnotherClient || reason == AVCaptureSessionInterruptionReason.videoDeviceInUseByAnotherClient {
				showResumeButton = true
			}
		}
	}
	
	func sessionInterruptionEnded(notification: NSNotification) {
		print("Capture session interruption ended")
		
	}
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            default: return nil
        }
    }
}

extension AVCaptureDeviceDiscoverySession {
	func uniqueDevicePositionsCount() -> Int {
		var uniqueDevicePositions = [AVCaptureDevicePosition]()
		
		for device in devices {
			if !uniqueDevicePositions.contains(device.position) {
				uniqueDevicePositions.append(device.position)
			}
		}
		
		return uniqueDevicePositions.count
	}
}

//
//  AcceptViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/16/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit

class AcceptViewController: ViewController {

    internal var photoControllerDelegate : MoleMapperPhotoController!
    internal var image: UIImage!
    
    convenience init(with delegate: MoleMapperPhotoController, image: UIImage) {
        self.init(nibName: nil, bundle: nil)
        photoControllerDelegate = delegate
        self.image = image
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.backgroundColor = .white
        let imageView = UIImageView()
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        
        var offset = CGFloat(0.0)
        if let nav = self.navigationController {
            offset += nav.navigationBar.bounds.height
        }
        offset += UIApplication.shared.statusBarFrame.size.height
        
        var adjustedFrame = self.view.frame
        adjustedFrame.origin.y += offset
        adjustedFrame.size.height -= offset
        
        let controlToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
        controlToolbar.sizeToFit()
        controlToolbar.tintColor = .white
        controlToolbar.barTintColor = .black
        adjustedFrame.size.height -= controlToolbar.bounds.height
        let retakeButton = UIBarButtonItem(title: "Retake", style: .plain,
                                           target: photoControllerDelegate,
                                           action: #selector(MoleMapperPhotoController.onRetake))
        
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let usePhotoButton = UIBarButtonItem(title: "Use Photo", style: .plain,
                                                 target: photoControllerDelegate,
                                                 action: #selector(MoleMapperPhotoController.onUsePhoto))
        
        controlToolbar.setItems([retakeButton, spacer, usePhotoButton], animated: false)
        controlToolbar.frame.origin.y = UIScreen.main.bounds.height - controlToolbar.frame.height
        self.view.addSubview(controlToolbar)
        imageView.frame = adjustedFrame
        self.view.addSubview(imageView)
        imageView.image = self.image
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

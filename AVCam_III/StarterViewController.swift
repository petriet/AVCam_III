//
//  StarterViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/13/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit

class StarterViewController: UIViewController, MoleMapperPhotoControllerDelegate {

    var myCamera: MoleMapperPhotoController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func onSwiftNavigationController(_ sender: Any) {
        let myNav = NavigationViewController()
        self.show(myNav, sender: nil)
    }

    @IBAction func onSwiftModal(_ sender: Any) {
        myCamera = MoleMapperPhotoController(withDelegate: self)
        myCamera!.showControls = true
        self.show(myCamera!, sender: nil)
    }
    
    func moleMapperPhotoControllerDidTakePictures(_ jpegData: Data?, displayPhoto: UIImage?, lensPosition: Float) {
        print("StarterViewController : moleMapperPhotoControllerDidTakePictures")
        self.myCamera?.dismiss(animated: true, completion: nil)
    }
    
    func moleMapperPhotoControllerDidCancel(_ controller: MoleMapperPhotoController) {
        self.myCamera?.dismiss(animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

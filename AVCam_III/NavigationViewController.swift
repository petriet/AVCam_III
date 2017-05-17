//
//  NavigationViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/13/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit
//import AVFoundation

// Parent Protocol
protocol ControllerDelegate {
    func onNext()
    func onPrev()
    func onDone()
    func onCancel()
}

extension NavigationControllerEx: ControllerDelegate, MoleMapperPhotoControllerDelegate {
    // ControllerDelegate
    internal func onCancel() {
        print("NavigationControllerEx onCancel")
        self.dismiss(animated: true, completion: nil)
    }

    internal func onPrev() {
        print("NavigationControllerEx onPrev")
    }

    internal func onNext() {
        print("NavigationControllerEx onPrev")
    }
    
    internal func onDone() {
        print("NavigationControllerEx onPrev")
        self.dismiss(animated: true, completion: nil)
    }
    
    // MoleMappePhotoDelegate
    internal func moleMapperPhotoControllerDidTakePictures(_ jpegData: Data?, displayPhoto: UIImage?, lensPosition: Float) {
        print("NavigationControllerEx recievePhoto")
    }
    internal func moleMapperPhotoControllerDidCancel(_ controller: MoleMapperPhotoController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

class NavigationControllerEx: UINavigationController {
    
}

class NavigationViewController: NavigationControllerEx {

    var VC1: ViewController?
//    var VC2: SecondViewController!
    var VC2: NavMMViewController!
    var VC3: ThirdViewController!
    var currentView = Int(1)
    
    convenience init() {
        let tmpvc = ViewController()
        self.init(rootViewController: tmpvc)
        VC1 = tmpvc
        VC1?.controllerDelegate = self
        VC2 = NavMMViewController(withDelegate: self)
        VC2.letUserApprovePhoto = false
        VC3 = ThirdViewController(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: ControllerDelegate overrides
    
    // Wonky magic number navigation (this is just a super temporary vehicle to test a new camera controller)
    override func onNext() {
        print("onNext")
        if currentView == 1 {
            self.pushViewController(self.VC2, animated: true)
            currentView += 1
        } else if currentView == 2 {
            self.pushViewController(self.VC3, animated: true)
            currentView += 1
        }
    }
    override func onPrev() {
        print("onPrev")
        if currentView == 3 {
            self.popViewController(animated: true)
            currentView -= 1
        } else if currentView == 2 {
            self.popViewController(animated: true)
            currentView -= 1
        }
    }

    // MARK: MoleMapperPhotoDelegate overrides
    
    override func moleMapperPhotoControllerDidTakePictures(_ jpegData: Data?, displayPhoto: UIImage?, lensPosition: Float) {
        print("moleMapperPhotoControllerDidTakePictures")
        if displayPhoto != nil {
            self.VC3.setPhotoToDisplay(photoImage: displayPhoto!)
        }
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

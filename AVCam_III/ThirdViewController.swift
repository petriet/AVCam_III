//
//  ThirdViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/13/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit

class ThirdViewController: UIViewController {
    var controllerDelegate: NavigationControllerEx!
    var photoView = UIImageView()
    
    convenience init(_ delegate: NavigationControllerEx) {
        self.init(nibName: nil, bundle: nil)
        controllerDelegate = delegate
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.darkGray
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Prev", style: .plain,
                                                                target: controllerDelegate,
                                                                action: #selector(NavigationControllerEx.onPrev))
        
        self.navigationItem.title = ""
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done,
                                                                 target: controllerDelegate,
                                                                 action: #selector(NavigationControllerEx.onDone))
        self.photoView.frame = self.view.frame
        print("self.photoView.frame = \(self.photoView.frame)")
        self.photoView.contentMode = .scaleAspectFit
        self.view.addSubview(self.photoView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setPhotoToDisplay(photoImage: UIImage) {
        print("about to implement setPhotoToDisplay")
        print("sizes of interest:")
        print("UIImage: \(photoImage.size)")
        print("View frame: \(self.view.frame)")
        self.photoView.image = photoImage
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

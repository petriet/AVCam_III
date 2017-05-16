//
//  NavMMViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/15/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit

class NavMMViewController: MoleMapperPhotoController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Prev", style: .plain,
                                                                target: controllerDelegate,
                                                                action: #selector(NavigationControllerEx.onPrev))
        
        self.navigationItem.title = "Tap to Snap"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done,
                                                                 target: controllerDelegate,
                                                                 action: #selector(NavigationControllerEx.onNext))
        
//        self.showControls = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

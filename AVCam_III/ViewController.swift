//
//  ViewController.swift
//  AVCam_III
//
//  Created by Tracy Petrie on 5/13/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

import UIKit


class ViewController: UIViewController {
    
    var controllerDelegate: NavigationControllerEx!

    convenience init(_ delegate: NavigationViewController) {
        self.init(nibName: nil, bundle: nil)
        controllerDelegate = delegate
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain,
                                                                target: controllerDelegate,
                                                                action: #selector(NavigationControllerEx.onCancel))
        
        self.navigationItem.title = ""
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done,
                                                                 target: controllerDelegate,
                                                                 action: #selector(NavigationControllerEx.onNext))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


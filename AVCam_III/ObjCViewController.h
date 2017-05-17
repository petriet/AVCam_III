//
//  ObjCViewController.h
//  AVCam_III
//
//  Created by Tracy Petrie on 5/15/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVCam_III-Swift.h"

// http://stackoverflow.com/questions/36629829/using-an-implementation-of-a-swift-protocol-within-obj-c
//@protocol MoleMapperPhotoControllerDelegate;


@interface ObjCViewController : UIViewController <MoleMapperPhotoControllerDelegate>

@end

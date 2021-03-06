//
//  ObjCViewController.m
//  AVCam_III
//
//  Created by Tracy Petrie on 5/15/17.
//  Copyright © 2017 Tracy Petrie. All rights reserved.
//

#import "ObjCViewController.h"


@interface ObjCViewController ()
@property MoleMapperPhotoController *cameraController;
@end

@implementation ObjCViewController 

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated: true completion: nil ];
}
- (IBAction)onCamera:(id)sender {
    self.cameraController = [[MoleMapperPhotoController alloc] initWithDelegate:(id<MoleMapperPhotoControllerDelegate>)self];
    self.cameraController.showControls = true;
    
    [self showViewController: self.cameraController sender:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - MoleMapperPhotoControllerDelegate

- (void)moleMapperPhotoControllerDidTakePictures:(NSData*)jpegData
                                    displayPhoto: (UIImage*)displayPhoto
                                    lensPosition: (float) lensPosition
{
    if (jpegData != NULL) {
        NSLog(@"jpeg data has %lu bytes", (unsigned long)[jpegData length]);
    }
    NSLog(@"Obj-C call receiving image data");
}

- (void)moleMapperPhotoControllerDidCancel:(MoleMapperPhotoController*)controller
{
    NSLog(@"ObjC moleMapperPhotoControllerDidCancel");

    [[self cameraController] dismissViewControllerAnimated:true completion:nil];
}

@end

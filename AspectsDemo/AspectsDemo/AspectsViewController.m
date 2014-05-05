//
//  AspectsViewController.m
//  AspectsDemo
//
//  Created by Peter Steinberger on 05/05/14.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import "AspectsViewController.h"
#import "Aspects.h"

@implementation AspectsViewController

- (IBAction)buttonPressed:(id)sender {
    UIViewController *testController = [[UIImagePickerController alloc] init];

    testController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:testController animated:YES completion:NULL];

    // We are interested in being notified when the controller is being dismissed.
    [testController aspect_hookSelector:@selector(viewWillDisappear:) withOptions:0 usingBlock:^(id instance, NSArray *arguments) {
        UIViewController *controller = instance;
        if (controller.isBeingDismissed || controller.isMovingFromParentViewController) {
            [[[UIAlertView alloc] initWithTitle:@"Popped" message:@"Hello from Aspects" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil] show];
        }
    } error:NULL];

    // Hooking dealloc is delicate, only AspectPositionBefore will work here.
    [testController aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionBefore usingBlock:^(id instance, NSArray *arguments) {
        NSLog(@"Controller is about to be deallocated: %@", instance);
    } error:NULL];
}

@end

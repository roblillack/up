//
//  UpController.h
//  Up!
//
//  Created by Robert Lillack on 28.12.08.
//  Copyright 2008 burningsoda.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PreviewView.h"

@interface UpController : NSWindowController {
    BOOL userIsResizing;
    NSUInteger pictureSize;
    float pictureQuality;
    float pictureSharpen;
    float pictureContrast;
    
    NSUInteger outputWidth;
    NSUInteger outputHeight;

    CIImage *inputImage;
    CIImage *processedImage;
    
    NSWindow *previewWindow;
    NSData *outputData;
    
    NSTimer *previewTimer;
    
    // The raw data of the dragged image
    IBOutlet NSData *pictureData;
    NSData *oldPictureData;

    // The ImageWell holding the dragged image
    IBOutlet NSImageView *picture;
    
    IBOutlet NSButton *uploadButton;

    IBOutlet NSTextField *pictureSizeLabel;
    IBOutlet NSSlider *pictureSizeSlider;
    IBOutlet NSSlider *pictureQualitySlider;
    IBOutlet NSTextField *pictureQualityPercentLabel;
    
    IBOutlet NSImageView *imageWell;
    IBOutlet NSWindow *mainWindow;
    
    IBOutlet NSPopUpButton *blogAccountSelector;
    IBOutlet NSProgressIndicator *progress;
    
    // Settings
    IBOutlet NSPanel *settingsPanel;
    IBOutlet NSTextField *inputUsername;
    IBOutlet NSSecureTextField *inputPassword;
    IBOutlet NSTextField *inputUrl;
    IBOutlet NSProgressIndicator *settingsProgress;
    IBOutlet NSSegmentedControl *addRemoveBlogConfigurationControl;
}

- (CIImage*) processImage: (CIImage*)input withHighScalingQuality: (BOOL)highScalingQuality;
- (void) updatePreviewWithFastRendering: (BOOL)fast;
- (IBAction) updatePreview: (id)sender;
- (CIImage*) getInputImage;

@end

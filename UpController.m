//
//  UpController.m
//  Up!
//
//  Created by Robert Lillack on 28.12.08.
//  Copyright 2008 burningsoda.com. All rights reserved.
//

#import "UpController.h"

@implementation UpController

- (void) awakeFromNib {
    NSLog(@"I'm awake now.");
    NSLog(@"Initializing “UpController”");

    NSUserDefaults *cfg = [NSUserDefaults standardUserDefaults];

    pictureSize = [cfg integerForKey:@"pictureSize"];
    if ((pictureSize = [cfg integerForKey:@"pictureSize"]) == 0) {
        pictureSize = 400;
    }
    
    if ((pictureQuality = [cfg floatForKey:@"pictureQuality"]) == 0.0) {
        pictureQuality = 0.8;
    }
    
    if ((pictureSharpen = [cfg floatForKey:@"pictureSharpen"]) == 0.0) {
        pictureSharpen = 0.8;
    }
    
    if ((pictureContrast = [cfg floatForKey:@"pictureContrast"]) == 0.0) {
        pictureContrast = 1.1;
    }
    
    // contains the readily rendered data
    outputData = nil;
    
    // a preview window
    previewWindow = nil;

    // will set up the percent label and stuff
    [self updatePreview: self];
}

// this method applies all necessary CI filters to the given image and returns
// the result (still, no rendering takes place)
- (CIImage*) processImage: (CIImage*)input
   withHighScalingQuality: (BOOL)highScalingQuality {
    NSUInteger maxSize = pictureSize;

    // calculate the new width and height
    NSUInteger oldWidth = CGRectGetWidth([input extent]);
    NSUInteger oldHeight = CGRectGetHeight([input extent]);
    NSUInteger newWidth = 0;
    NSUInteger newHeight = 0;
    double scaleFactor = 1.0;
    if (oldWidth > oldHeight) {
        newWidth = maxSize;
        newHeight = round(maxSize * oldHeight / oldWidth);
        scaleFactor = (double) (maxSize + 4) / (double) oldWidth;
    } else {
        // todo: hier muss ein bug sein!
        newHeight = maxSize;
        newWidth = round(maxSize * oldWidth / oldHeight);
        scaleFactor = (double) (maxSize + 4) / (double) oldHeight;
    }
    ///NSLog(@"%ux%u --> %ux%u (factor: %@)", oldWidth, oldHeight, newWidth, newHeight, [NSNumber numberWithDouble: scaleFactor]);

    // downsample
    CIFilter *scaleFilter = nil;
    if (highScalingQuality) {
        // lanczos downsampling produces bad artefacts
        // in high contrast areas when the scalefactor is ~0.55 or smaller
        // and JPEG compression is used to encode the ouput for me.
        // we try to circumvent this (bug?) here, by prescaling
        // using a simple affine transform to keep the lanczos scale factor up
        /*if (scaleFactor < 0.6) {
            NSAffineTransform *trans = [NSAffineTransform transform];
            [trans scaleBy: scaleFactor / 0.6];

            CIFilter *preScaleFilter = [CIFilter filterWithName: @"CIAffineTransform"];
            [preScaleFilter setDefaults];
            [preScaleFilter setValue: input
                              forKey: @"inputImage"];
            [preScaleFilter setValue: trans
                              forKey: @"inputTransform"];

            scaleFilter = [CIFilter filterWithName: @"CILanczosScaleTransform"];
            [scaleFilter setDefaults];
            [scaleFilter setValue: [preScaleFilter valueForKey: @"outputImage"]
                           forKey: @"inputImage"];
            [scaleFilter setValue: [NSNumber numberWithDouble: 0.6]
                           forKey: @"inputScale"];
        } else {*/
            scaleFilter = [CIFilter filterWithName: @"CILanczosScaleTransform"];
            [scaleFilter setDefaults];
            [scaleFilter setValue: input
                           forKey: @"inputImage"];
            [scaleFilter setValue: [NSNumber numberWithDouble: scaleFactor]
                           forKey: @"inputScale"];
        //}
    } else {
        scaleFilter = [CIFilter filterWithName: @"CIAffineTransform"];
        [scaleFilter setDefaults];
        [scaleFilter setValue: input
                       forKey: @"inputImage"];
        NSAffineTransform *trans = [NSAffineTransform transform];
        [trans scaleBy: scaleFactor];
        [scaleFilter setValue: trans
                       forKey: @"inputTransform"];
    }

    CIFilter *sharpenFilter = [CIFilter filterWithName: @"CISharpenLuminance"];
    [sharpenFilter setDefaults];
    [sharpenFilter setValue: [NSNumber numberWithFloat: pictureSharpen]
                     forKey: @"inputSharpness"];
    [sharpenFilter setValue: [scaleFilter valueForKey: @"outputImage"]
                     forKey: @"inputImage"];

    CIFilter *contrastFilter = [CIFilter filterWithName: @"CIColorControls"];
    [contrastFilter setDefaults];
    [contrastFilter setValue: [NSNumber numberWithFloat: pictureContrast]
                      forKey: @"inputContrast"];
    [contrastFilter setValue: [sharpenFilter valueForKey: @"outputImage"]
                      forKey: @"inputImage"];

    CIFilter *cropFilter = [CIFilter filterWithName: @"CICrop"];
    [cropFilter setDefaults];
    [cropFilter setValue: [CIVector vectorWithX: 2.0
                                              Y: 2.0
                                              Z: newWidth
                                              W: newHeight]
                  forKey: @"inputRectangle"];
    [cropFilter setValue: [contrastFilter valueForKey: @"outputImage"]
                  forKey: @"inputImage"];

    outputWidth = newWidth;
    outputHeight = newHeight;

    return [cropFilter valueForKey: @"outputImage"];
}

- (IBAction) updatePreview: (id)sender {
    // if the user changed the “compression quality” do the real encoding
    // process for him to see the resulting picture quality and file size.
    [self updatePreviewWithFastRendering: !(sender == pictureQualitySlider)];
}

- (void) updatePreviewWithFastRendering: (BOOL)skipEncodeDecode {
    //NSLog(@"updatePreview");
    [pictureQualityPercentLabel setStringValue: [NSString stringWithFormat:@"%u",
                                                 round(pictureQuality*100)]];
    [pictureSizeLabel setStringValue:[NSString stringWithFormat:@"%upx", pictureSize]];
    
    if ([pictureSizeSlider intValue] != pictureSize) {
        [pictureSizeSlider setIntValue: pictureSize];
    }
    
    if (pictureData == nil) {
        return;
    }
    
    processedImage = [self processImage: [self getInputImage]
                 withHighScalingQuality: !skipEncodeDecode];

    if (skipEncodeDecode == NO) {
        // render the result into a bitmap
        NSBitmapImageRep* outputBitmap = [[NSBitmapImageRep alloc] initWithCIImage: processedImage]; 
        
        // and convert the bitmap into the wanted output format
        NSDictionary *props = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:
                                                                    [NSNumber numberWithFloat: pictureQuality],
                                                                    [NSNumber numberWithBool: YES],
                                                                    nil]
                                                          forKeys: [NSArray arrayWithObjects:
                                                                    NSImageCompressionFactor,
                                                                    NSImageProgressive,
                                                                    nil]];
        outputData = [outputBitmap representationUsingType: NSJPEGFileType
                                                properties: props];
    }
    
    // show a preview window
    NSUInteger contentWidth = outputWidth + 30;
    NSUInteger contentHeight = outputHeight + 30;
    PreviewView *imageView;
    if (previewWindow) {
        // already open? then resize (around the center, of course)
        NSRect oldFrame = [previewWindow frame];
        NSRect oldContentRect = [previewWindow contentRectForFrameRect: oldFrame];
        NSRect newFrame = [previewWindow frameRectForContentRect: NSMakeRect(oldContentRect.origin.x - (contentWidth - oldContentRect.size.width)/2,
                                                           oldContentRect.origin.y - (contentHeight - oldContentRect.size.height)/2,
                                                           contentWidth, contentHeight)];
        // try to make sure, the window does not leave the screen
        newFrame = [previewWindow constrainFrameRect: newFrame
                                            toScreen: [previewWindow screen]];
        // sending setFrame:display: does NOT invoke willResize:toSize:
        [previewWindow setFrame: newFrame
                        display: YES];
        imageView = [previewWindow contentView];
    } else {
        previewWindow = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, contentWidth, contentHeight)
                                                    styleMask: NSTitledWindowMask | NSResizableWindowMask
                                                      backing: NSBackingStoreBuffered
                                                        defer: NO];
        [previewWindow setPreferredBackingLocation: NSWindowBackingLocationVideoMemory];
        [previewWindow setFrameAutosaveName: @"preview"];
        [previewWindow setDelegate: self];
        // not needed
        [previewWindow setPreservesContentDuringLiveResize: NO];
        // no overlapping views, use some optimization
        [previewWindow useOptimizedDrawing: YES];
        [previewWindow setMovableByWindowBackground: YES];

        imageView = [[PreviewView alloc] initWithFrame: [previewWindow frame]];
        [previewWindow setContentView: imageView];
        [previewWindow makeKeyAndOrderFront: self];
    }
    
    [previewWindow setContentAspectRatio: NSMakeSize(outputWidth+30, outputHeight+30)];

    if (skipEncodeDecode) {
        [previewWindow setTitle: [NSString stringWithFormat: @"Preview: %u ⨉ %u px, … KiB", outputWidth, outputHeight]];
        //@previewWindow.contentView.setImage(getNSImageFromCIImage(@processedImage))
        [imageView setImage: processedImage];
        
        // setup a timer to display a REAL preview (encoded to the output format, scaled using better quality)
        // after a short time interval. this speeds up the live display enormously
        if (previewTimer != nil) {
            // exists, but did not fire yet? good, just postpone it
            [previewTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
            //NSLog(@"Timer postponed");
        } else {
            //NSLog(@"Starting finalization timer");
            previewTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5
                                                            target: self
                                                          selector: @selector(finalizePreview:)
                                                          userInfo: nil
                                                           repeats: NO];
            //NSLog(@"Finalization Timer started");
        }
    } else {
        [previewWindow setTitle: [NSString stringWithFormat: @"Preview: %u ⨉ %u px, %.1f KiB", outputWidth, outputHeight, round([outputData length]/102.4)/10.0]];
        [imageView setImage: [[CIImage alloc] initWithData: outputData]];
        // either we're called by the fired timer, or we don't need it, so:
        previewTimer = nil;
    }
}

- (void) finalizePreview: (NSTimer*)theTimer {
    previewTimer = nil;
    if (userIsResizing) {
        //NSLog(@"User is Resizing …");
        return;
    }
    //NSLog(@"Finalizing Picture");
    [self updatePreviewWithFastRendering: NO];
}

- (CIImage*) getInputImage {
    // pictureData did not change? right, so...
    if (inputImage != nil && [pictureData isEqualToData: oldPictureData]) {
        return inputImage;
    }

    // using CIImage.imageWithData(@pictureData) would not
    // decode the image data right now, but do it every
    // time the final result gets rendered, so wie
    // decode it into a bitmap representation NOW
    NSBitmapImageRep *bitmapRep = nil;
    // check, if there's a bitmapimagerep backing our
    // imagewell's nsimage (true, if a bitmap dragged to it)
    NSEnumerator *enumerator = [[[picture image] representations] objectEnumerator];
    id r;
    while (r = [enumerator nextObject]) {
        if ([r isKindOfClass: [NSBitmapImageRep class]]) {
            bitmapRep = r;
            NSLog(@"Found Bitmap Representation in File");
            break;
        }
    }

    // no? vector file dragged here? then render it into a bitmap:
    if (bitmapRep == nil) {
        [[picture image] lockFocus];
        bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: NSMakeRect(0, 0, [[picture image] size].width, [[picture image] size].height)];
        [[picture image] unlockFocus];
    }

    // aight! save for later use.
    inputImage = [[CIImage alloc] initWithBitmapImageRep: bitmapRep];
    oldPictureData = pictureData;

    return inputImage;
}

- (NSSize) scaleSize: (NSSize)input toSquareOfSideLength: (float)length {
    if (input.width > input.height) {
        return NSMakeSize(length, length * input.height / input.width);
    } else {
        return NSMakeSize(length * input.width / input.height, length);
    }
}

- (NSSize) windowWillResize: (NSWindow*)window toSize: (NSSize)proposedSize {
    if (window != previewWindow) {
        return proposedSize;
    }
    
    // to prevent double updating
    userIsResizing = YES;

    // don't let it get too small
    NSSize contentSize = [window contentRectForFrameRect: NSMakeRect(0, 0, proposedSize.width, proposedSize.height)].size;
    if (contentSize.width < 130.0 && contentSize.height < 130.0) {
        NSSize newSize = [self scaleSize: contentSize
                    toSquareOfSideLength: 130.0];
        return [window frameRectForContentRect: NSMakeRect(0, 0, newSize.width, newSize.height)].size;
    }
    
    // the proposed Size should work because the aspect ratio is set
    return proposedSize;
}

- (void) windowDidResize: (NSNotification*)notification {
    if ([notification object] != previewWindow || userIsResizing == NO) {
        return;
    }

    // the user did resize the window
    // and the previewview updated the image by doing a simple scale (stage 1)
    // we calculate a new picturesize and call stage 2
    // (which will resize the window to make it pixel-perfect and call stage 3)
    pictureSize = [previewWindow contentRectForFrameRect: [previewWindow frame]].size.width - 30;
    
    // the next resize may be someone else(?) again...
    userIsResizing = NO;
    [self updatePreviewWithFastRendering: YES];
}

- (IBAction) uploadPicture: (id)sender {
    // nothing dragged here, eh?
    if (!pictureData) {
        return;
    }
    
    // there's no data to send there or
    // the timer's still waiting for the final
    // run, do it now
    if (!outputData || previewTimer != nil) {
        [self finalizePreview: previewTimer];
    }
        
    // start the progress bar (how lame)		
	[progress startAnimation: self];
        
    // retrieve the selected blog config
    NSDictionary *selectedDict = [[blogConfigurationController arrangedObjects] objectAtIndex: [blogAccountSelector indexOfSelectedItem]];
        
    // get the output template and replace the first values
    // as they may change while we upload
    // (url will be inserted when we know it)
    //template = selected_nsdict.objectForKey('template').mutableCopy
   	//template.gsub!(/%width%/, "#{@outputWidth}")
	//template.gsub!(/%height%/, "#{@outputHeight}")
        
    // pack up all the necessary data for the worker thread
    // i did not use :symbols here because if i choose to use
    // cocoa threads, this structure will get converted to
    // a nsdict with strings as keys anyway
    [self uploadData: outputData
        withFilename: @"bla.jpg"
        toBlogWithId: [selectedDict objectForKey: @"active_id"]
            username: [selectedDict objectForKey: @"username"]
            password: [selectedDict objectForKey: @"password"]
               atUrl: [NSURL URLWithString: [selectedDict objectForKey: @"url"]]];
/*        work = {
            'url' => selected_nsdict.objectForKey('url').to_s,
            'blogid' => selected_nsdict.objectForKey('active_id').to_s,
            'username' => selected_nsdict.objectForKey('username').to_s,
            'password' => selected_nsdict.objectForKey('password').to_s,
            'template' => template,
            'data' => @outputData,
        }*/
}

- (void) uploadData: (NSData*)data
       withFilename: (NSString*)filename
       toBlogWithId: (NSString*)blogid
           username: (NSString*)username
           password: (NSString*)password
              atUrl: (NSURL*)url {
    
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: url];
    XMLRPCConnectionManager *manager = [XMLRPCConnectionManager sharedManager];
    
    NSDictionary *dataDict = [NSDictionary dictionaryWithObjects: (id[]){@"image/jpeg", data, filename}
                                                         forKeys: (id[]){@"type", @"bits", @"name"}
                                                           count: 3];
    [request setMethod: @"metaWeblog.newMediaObject"
        withParameters: [NSArray arrayWithObjects: (id[]){blogid, username, password, dataDict}
                                            count: 4]];
    
    NSLog(@"Request body: %@", [request body]);

    [manager spawnConnectionWithXMLRPCRequest: request delegate: self];
    [request release];
//  result['template'] = work['template'].gsub(/%url%/, result['url'])
}

- (void)request: (XMLRPCRequest *)request didReceiveResponse: (XMLRPCResponse *)response {
    NSLog(@"Response: %@", [response body]);
    
    [progress stopAnimation: self];
    
    // open up some alert sheet, and tell the user about the result
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: @"OK"];
    
    NSLog(@"REPONSE: %@", [[response object] valueForKey: @"url"]);
    
    // has error || no url
    if ([response isFault] ||
        ![[response object] isKindOfClass: [NSDictionary class]] ||
        ![[response object] valueForKey: @"url"]) {
        [alert setMessageText: @"Error uploading file."];
        if ([response isFault]) {
            [alert setInformativeText: [response faultString]];
        } else if (![[response object] valueForKey: @"url"]) {
            [alert setInformativeText: @"No URL in server response."];
        } else {
	        [alert setInformativeText: [response valueForKey: @"error"]];
        }
        [NSApp requestUserAttention: NSCriticalRequest];
    } else {
    	[alert setMessageText: @"File successfully uploaded."];
        /* not result.key? 'template' or
         result['template'] == nil or
         result['template'].length < 1 */
	    if (YES) {
        	[alert setInformativeText: [NSString stringWithFormat:
                                        @"The URL (%@) has been copied to the clipboard.",
                                        [[response object] valueForKey: @"url"]]];
            [self copyToPasteboard: [[response object] valueForKey: @"url"]];
        } else {
			[alert setInformativeText: @"The filled template has been copied to the pasteboard."];
            [self copyToPasteboard: @"OJ1oj1oj1o!JO!J1"];
        }
	    [NSApp requestUserAttention: NSInformationalRequest];
    }
    
    [alert beginSheetModalForWindow: mainWindow
                      modalDelegate: self
                     didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
                        contextInfo: nil];
}

- (void) copyToPasteboard: (NSString*)str {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	[pboard declareTypes: [NSArray arrayWithObject: NSStringPboardType]
                   owner: self];
    [pboard setString: str forType: NSStringPboardType];
}

- (void) alertDidEnd: (NSAlert*)alert returnCode: (NSInteger)returnCode contextInfo: (id)contextInfo {
	[alert release];
}

@end
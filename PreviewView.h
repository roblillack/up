//
//  PreviewView.h
//  Up!
//
//  Created by Robert Lillack on 28.12.08.
//  Copyright 2008 burningsoda.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface PreviewView : NSView {
    CIImage *image;
}

- (void) setImage: (CIImage*)img;
@end

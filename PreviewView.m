//
//  PreviewView.m
//  Up!
//
//  Created by Robert Lillack on 28.12.08.
//  Copyright 2008 burningsoda.com. All rights reserved.
//

#import "PreviewView.h"


@implementation PreviewView

- (id) initWithFrame: (NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void) setImage: (CIImage*) img {
    if (img == nil) return;
    [image release];
    [img retain];
    image = img;
    [self setNeedsDisplay: TRUE];
}

- (void) drawRect: (NSRect) rect {
    if (image == nil) {
        return;
    }

    int imageW = floor(CGRectGetWidth([image extent]));
    //int imageH = floor(CGRectGetHeight([image extent]));
    int windowW = floor([self bounds].size.width);
    int windowH = floor([self bounds].size.height);

    CIContext *context = [[NSGraphicsContext currentContext] CIContext];

    // PreviewView can scale the given image on it's own.
    // This first stage of drawing is needed when stage2
    // is not rendered fast enough and the window size did change a LOT.
    // We try to prevent the window from being shown with a wrong sized image
    if (imageW + 30 != windowW) {
        [context drawImage: image
                    inRect: CGRectMake(15, 15, windowW - 30, windowH - 30)
                  fromRect: [image extent]];
    } else {
        [context drawImage: image
                   atPoint: CGPointMake(15, 15)
                  fromRect: [image extent]];
    }
}

@end

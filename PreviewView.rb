#
#  PreviewView.rb
#  Up!
#
#  Created by Robert Lillack on 21.02.08.
#  Copyright (c) 2008 burningsoda.com. All rights reserved.
#

require 'osx/cocoa'

class PreviewView <  OSX::NSView

  def setImage(image)
    @image = image
    setNeedsDisplay(true)
  end

  def drawRect(rect)
    return unless @image
    
    imageW = CGRectGetWidth(@image.extent).floor
    imageH = CGRectGetHeight(@image.extent).floor
    windowW = bounds.size.width.floor
    windowH = bounds.size.height.floor
    
    context = NSGraphicsContext.currentContext.CIContext                                                                          

	# PreviewView can scale the given image on it's own.
	# This first stage of drawing is needed when stage2
	# is not rendered fast enough and the window size did change a LOT.
	# We try to prevent the window from bein shown with a wrong sized image
    if imageW + 30 != windowW then
    	context.drawImage_inRect_fromRect(@image, CGRectMake(15, 15, windowW - 30, windowH - 30), @image.extent)
    else
    	context.drawImage_atPoint_fromRect(@image, CGPointMake(15, 15), @image.extent)
    end
  end

end

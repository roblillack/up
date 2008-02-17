#
#  Up!
#
#  Created by Robert Lillack on 09.12.07.
#
#  ©2007–2008 burningsoda.com
#             All rights reserved.
#

# NSArrayController anlegen:
# - content array binden an Preferences.values.<key>
# - [x] handles content as compound value!!! (sonst kein sichern moeglich)

require 'xmlrpc/client'
require 'pp'

class Up < NSWindowController
	ib_outlets :mainWindow, :inputUrl, :inputUsername, :inputPassword,
	           :picture, :progress, :uploadButton, :fileName, :addRemoveBlogConfigurationControl,
			   :blogConfigurationList, :blogConfigurationController, :blogIdController,
			   :settingsProgress, :settingsPanel, :imageWell,
               :blogAccountSelector, :pictureQualityPercentLabel
	attr_accessor :settingsShown, :filePath

    # original picture
    attr_accessor :pictureData
    # max width or height in pixels -- bound to a slider
    attr_accessor :pictureSize
    # the picture quality (only used for JPEG or JPEG2000 format)
    attr_accessor :pictureQuality
        
    ib_action :windowShouldClose do |sender|
        NSApp.stop(self)
        true
    end
	
	ib_action :showSettings
	def showSettings(sender)
		OSX::NSApp.beginSheet_modalForWindow_modalDelegate_didEndSelector_contextInfo_(
			@settingsPanel, @mainWindow, self, nil, nil
		)
	end
    
    ib_action :hideSettings
	def hideSettings(sender)
		@settingsPanel.orderOut(@settingsPanel)
		OSX::NSApp.endSheet(@settingsPanel)
	end
    
    def applicationWillUnhide(notification)
        puts 'Application will unhide.'
    end

    def applicationDidUnhide(notification)
        puts 'Application did unhide.'
    end
    
    def applicationWillTerminate(notification)
        puts 'Application will terminate.'
    end
    
    def applicationShouldTerminate(sender)
        puts 'Application should terminate'
        return true
    end
	
	def initialize
		puts "Initializing Controller “Up”"
        @pictureSize = 400
        @pictureQuality = 0.8
        # contains the readily rendered data
        @outputData = nil
        # a preview window
        @previewWindow = nil
   	end
    
    def awakeFromNib
        puts 'I\'m awake now.'
        # will set the percent label
        updatePreview
    end
    
    def applicationDidFinishLaunching(notification)
        puts 'Application did finish launching.'
    end
	
	def applicationWillFinishLaunching(notification)
		puts "applicationWillFinishLaunching"
	end
    
    ib_action :checkBlogIds
	def checkBlogIds(sender = nil)
		return if @inputUsername.stringValue.to_s == nil or @inputUsername.stringValue.to_s == '' or
				  @inputPassword.stringValue.to_s == nil or @inputPassword.stringValue.to_s == '' or
				  @inputUrl.stringValue.to_s == nil or @inputUrl.stringValue.to_s == ''
		@settingsProgress.startAnimation(self)
		begin
			c = XMLRPC::Client.new2(@inputUrl.stringValue.to_s)
			res = c.call('blogger.getUsersBlogs', "booyah", @inputUsername.stringValue.to_s, @inputPassword.stringValue.to_s)
		rescue Exception => e
			puts 'ERROR getting users\' blogs. ' + e.message
			res = []
		end
		#@selectBlogId.removeAllItems
		# TODO: clear!
		while @blogIdController.arrangedObjects.to_a.size > 0 do
			@blogIdController.removeObjectAtArrangedObjectIndex(0)
		end
		res.each do |b|
			next unless b.key? 'blogName' and b.key? 'blogid'
			@blogIdController.addObject({'id' => b['blogid'], 'name' => b['blogName']})
		end
        @blogIdContoller.setSelectionIndex(0)
		@settingsProgress.stopAnimation(self)
	end
	
    ib_action :addRemoveBlogConfiguration
	def addRemoveBlogConfiguration(sender = nil)
		if @addRemoveBlogConfigurationControl.selectedSegment == 0 then
			arrayObject = {	'title' => 'New Profile', 'url' => 'http://',
							'type' => 0,
							'available_ids' => [], 'active_id' => '',
							'username' => '', 'password' => '' }
			@blogConfigurationController.addObject(arrayObject)
			@blogConfigurationController.setSelectedObjects([arrayObject])
		else
			@blogConfigurationController.removeObjectAtArrangedObjectIndex(@blogConfigurationController.selectionIndex)
		end
	end
	
    def alertDidEnd_returnCode_contextInfo(alert, returnCode, contextInfo)
        alert.release
    end
    
    ib_action :uploadPicture
	def uploadPicture(sender)
		# nothing dragged here, eh?
		return unless @pictureData
		
		# there's no data to send there or
		# the timer's still waiting for the final
		# run, do it now
		finalizePreview if not @outputData or @previewTimer

		# start the progress bar (how lame)		
		@progress.startAnimation(self)
		
		# retrieve the selected blog config
        selected_nsdict = @blogConfigurationController.arrangedObjects.to_a[@blogAccountSelector.indexOfSelectedItem]
        
        # pack up all the necessary data for the worker thread
        # i did not use :symbols here because if i choose to use
        # cocoa threads, this structure will get converted to
        # a nsdict with strings as keys anyway
        work = {
            'url' => selected_nsdict.objectForKey('url').to_s,
            'blogid' => selected_nsdict.objectForKey('active_id').to_s,
            'username' => selected_nsdict.objectForKey('username').to_s,
            'password' => selected_nsdict.objectForKey('password').to_s,
            'data' => @outputData,
        }

        # and start it
        # ruby threads
        @workerthread = Thread.new(work) {|w| doHeftyWork(w)}
        # single threaded
        #doHeftyWork(work)
        # cocoa threads (will run single threaded...)
        #NSThread.detachNewThreadSelector_toTarget_withObject("doHeftyWork:", self, work)
    end
    
    # this one's called in the main thread, as soon as the upload thread finished
    def workReady(result)
    	# we may be called from a cocoa thread, as i tend
    	# to switch between those implementations...
        result = result.to_ruby if result.kind_of? NSObject
        
        # ruby threads? ok, then....
        @workerthread.join if @workerthread
        @workerthread = nil
        
        # yeah, right. shut up!
        @progress.stopAnimation(self)
        
        # open up some alert sheet, and tell the user about the result
		alert = OSX::NSAlert.alloc.init
		alert.addButtonWithTitle("OK")
        if result.key? 'error' then
            alert.setMessageText('Error uploading file.')
            alert.setInformativeText(result['error'])
            NSApp.requestUserAttention(NSCriticalRequest)
        elsif not result.key? 'url' then
            alert.setMessageText('Error uploading file.')
            NSApp.requestUserAttention(NSCriticalRequest)
            alert.setInformativeText('No URL in server response.')
        else
            alert.setMessageText('File successfully uploaded.')
            alert.setInformativeText('The URL (' + result['url'] +
                                     ') has been copied to the clipboard.')
            copyUrlToPasteboard(result['url'])
            NSApp.requestUserAttention(NSInformationalRequest)
        end
		alert.beginSheetModalForWindow_modalDelegate_didEndSelector_contextInfo(
			@mainWindow, self, "alertDidEnd:returnCode:contextInfo:", nil
		)
	end
	
	# this method applies all necessary CI filters to the given image and returns
	# the result (still, no rendering takes place)
	def processImage(inputImage, highScalingQuality = true)
        maxSize = @pictureSize.to_i
		
        # calculate the new width and height
        oldWidth = CGRectGetWidth(inputImage.extent)
        oldHeight = CGRectGetHeight(inputImage.extent)
        if oldWidth > oldHeight then
            newWidth = maxSize
            newHeight = (maxSize * oldHeight / oldWidth).floor
            scaleFactor = (maxSize + 4) / oldWidth
        else 
            newHeight = maxSize
            newWidth = (maxSize * oldWidth / oldHeight).floor
            scaleFactor = (maxSize + 4) / oldHeight
        end
        
        puts "max. Size: #{maxSize}"
        puts "actual Size: #{oldWidth}x#{oldHeight}"
        puts "resize factor: #{scaleFactor}"
        puts "new Size: #{scaleFactor * oldWidth}x#{scaleFactor * oldHeight}"
        puts "predicted new size: #{newWidth}x#{newHeight}"
        
        # downsample
        if highScalingQuality then
        	# lanczos downsampling produces bad artefacts
        	# in high contrast areas when the scalefactor is ~0.55 or smaller
        	# and JPEG compression is used to encode the ouput for me.
        	# we try to circumvent this (bug?) here, by prescaling
        	# using a simple affine transform to keep the lanczos scale factor up
        	if scaleFactor < 0.6 then
		        trans = NSAffineTransform.transform
    		 	trans.scaleBy(scaleFactor / 0.6)
        		preScaleFilter = CIFilter.filterWithName("CIAffineTransform")
        		preScaleFilter.setDefaults
        		preScaleFilter.setValue_forKey(inputImage, "inputImage")
	        	preScaleFilter.setValue_forKey(trans, "inputTransform")
		        
		        scaleFilter = CIFilter.filterWithName("CILanczosScaleTransform")
    		    scaleFilter.setDefaults()
        		scaleFilter.setValue_forKey(preScaleFilter.valueForKey("outputImage"), "inputImage")
        		scaleFilter.setValue_forKey(NSNumber.numberWithDouble(0.6), "inputScale")
        	else
		        scaleFilter = CIFilter.filterWithName("CILanczosScaleTransform")
    		    scaleFilter.setDefaults()
        		scaleFilter.setValue_forKey(inputImage, "inputImage")
        		scaleFilter.setValue_forKey(NSNumber.numberWithDouble(scaleFactor), "inputScale")
        	end
        else
	        scaleFilter = CIFilter.filterWithName("CIAffineTransform")
    	    scaleFilter.setDefaults()
        	scaleFilter.setValue_forKey(inputImage, "inputImage")
	        trans = NSAffineTransform.transform
    	 	trans.scaleBy(scaleFactor)
        	scaleFilter.setValue_forKey(trans, "inputTransform")
        end
        
        sharpenFilter = CIFilter.filterWithName("CISharpenLuminance")
        sharpenFilter.setDefaults()
        sharpenFilter.setValue_forKey(NSNumber.numberWithFloat(scaleFactor/10.0), "inputSharpness")
        sharpenFilter.setValue_forKey(scaleFilter.valueForKey("outputImage"), "inputImage")

        contrastFilter = OSX::CIFilter.filterWithName("CIColorControls")
        contrastFilter.setDefaults()
        contrastFilter.setValue_forKey(OSX::NSNumber.numberWithFloat(1.05), "inputContrast")
        contrastFilter.setValue_forKey(sharpenFilter.valueForKey("outputImage"), "inputImage")
        
        @outputWidth = newWidth
        @outputHeight = newHeight

        return contrastFilter.valueForKey("outputImage")
	end
	
	# wrapper function because i'm unable to let the nstimer
	# calls updatePreview(false) when it fires :(
	def finalizePreview
		updatePreview(false)
	end
	
	# shows or updates the Preview Window
	ib_action :updatePreview
	def updatePreview(skipEncodeDecode = true)
		@pictureQualityPercentLabel.setStringValue("#{(@pictureQuality.to_f*100).round}%")
		return unless @pictureData
		@processedImage = processImage(self.getInputImage, !skipEncodeDecode)
		
		if not skipEncodeDecode then
			# create a bitmap to render into
    	    outputBitmap = NSBitmapImageRep.alloc.initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel(
        	    nil, @outputWidth, @outputHeight, 8, 4, true, false, OSX::NSCalibratedRGBColorSpace, 0, 0
        	)
	        # render the CIImage into the BitmapImageRep
    	    outputContext = NSGraphicsContext.graphicsContextWithBitmapImageRep(outputBitmap).CIContext
        	outputContext.drawImage_atPoint_fromRect(
	        	@processedImage,
    	    	CGPointMake(0, 0),
        		CGRectMake(2, 2, @outputWidth, @outputHeight)
	        )

			# convert the bitmap into the wanted output format
    	    @outputData = outputBitmap.representationUsingType_properties(
	        	NSJPEGFileType,
    	    	{NSImageCompressionFactor => @pictureQuality,
    	    	 NSImageProgressive => NSNumber.numberWithBool(true)}
	        )
		end	    	
		
	    # show a preview window
	    contentWidth = @outputWidth + 30
	    contentHeight = @outputHeight + 30
        if @previewWindow then
        	# already open? then resize (animated around the center, of course)
        	oldFrame = @previewWindow.frame
        	oldContentRect = @previewWindow.contentRectForFrameRect(oldFrame)
        	newFrame = @previewWindow.frameRectForContentRect(
        		[oldContentRect.x - (contentWidth - oldContentRect.width)/2,
				 oldContentRect.y - (contentHeight - oldContentRect.height)/2,
				 contentWidth, contentHeight]
			)
			# try to make sure, the window does not leave the screen
			newFrame = @previewWindow.constrainFrameRect_toScreen(newFrame, @previewWindow.screen)
        	@previewWindow.setFrame_display_animate(newFrame, true, true)
        else
	        @previewWindow = NSWindow.alloc.initWithContentRect_styleMask_backing_defer(
    	    	[100, 100, contentWidth, contentHeight],
        		NSTitledWindowMask,
        		NSBackingStoreBuffered,
	        	false
	        )
	        # not needed
	        @previewWindow.setPreservesContentDuringLiveResize(false)
	        # no overlapping views, use some optimization
	        @previewWindow.useOptimizedDrawing(true)
	        @previewWindow.setMovableByWindowBackground(true)
	        @previewWindow.center
	        imageView = NSImageView.alloc.initWithFrame @previewWindow.frame
	        imageView.setImageScaling(NSScaleNone)
    	    @previewWindow.setContentView imageView
        	@previewWindow.makeKeyAndOrderFront self
	    end

        if skipEncodeDecode then
        	@previewWindow.setTitle("Processing Preview....")
        	@previewWindow.contentView.setImage(getNSImageFromCIImage(@processedImage))

	        # setup a timer to display a REAL preview (encoded to the output format, scaled using better quality)
    	    # after a short time interval. this speeds up the live display enormously
        	if @previewTimer then
	        	# exists, but did not fire yet? good, just postpone it
    	    	@previewTimer.setFireDate(NSDate.dateWithTimeIntervalSinceNow(0.1))
	        else
    	    	@previewTimer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(
    	    		0.1, self, "finalizePreview:", nil, false
    	    	)
	        end
        else
	        @previewWindow.setTitle("Preview: #{@outputWidth}⨉#{@outputHeight}px, #{(@outputData.length/102.4).to_i/10.0}KiB")
        	@previewWindow.contentView.setImage(NSImage.alloc.initWithData(@outputData))
        	
        	# either we're called by the fired timer, or we don't need it, so:
        	@previewTimer = nil
        end
   	end
    
    # this essentially is the upload thread
    def doHeftyWork(work)
        begin
            client = XMLRPC::Client.new2(work['url'])
            result = client.call('metaWeblog.newMediaObject', work['blogid'], work['username'], work['password'],
                                 {'type' => 'image/jpeg', 'bits' => XMLRPC::Base64.new(work['data'].rubyString)})
        rescue Exception => e
            result = { 'error' => e.message }
        end

		# tell the main thread about us being ready
        self.performSelectorOnMainThread_withObject_waitUntilDone("workReady:", result, false)
        
        return result
    end
    
    def copyUrlToPasteboard(url)
        pboard = OSX::NSPasteboard.generalPasteboard
        pboard.declareTypes_owner([OSX::NSStringPboardType], self)
        pboard.setString_forType(url, OSX::NSStringPboardType)
    end
    
    def getNSImageFromCIImage(ciimage)
	    ir = NSCIImageRep.imageRepWithCIImage(ciimage)
    	image = NSImage.alloc.initWithSize([ciimage.extent.size.width, ciimage.extent.size.height])
    	image.addRepresentation(ir)
	    return image
	end

    def getInputImage
    	starttime = Time.now
    	# pictureData did not change? right, so...
    	if @inputImage != nil and @oldPictureData == @pictureData then
	        puts "* returning InputImage: " + (Time.now - starttime).to_s
    		return @inputImage
    	end
    	
    	# using CIImage.imageWithData(@pictureData) would not
    	# decode the image data right now, but do it every
    	# time the final result gets rendered, so wie
    	# decode it into a bitmap representation NOW
    	bitmapRep = nil
    	# check, if there's a bitmapimagerep backing our
    	# imagewell's nsimage (true, if a bitmap dragged to it)
    	enumerator = @picture.image.representations.objectEnumerator
	    while r = enumerator.nextObject do
    	    if r.kind_of? NSBitmapImageRep then
        	    break
	        end
    	end
    	# no? vector file dragged here? then render it into a bitmap:
    	if not bitmapRep then
    		@picture.image.lockFocus
    		bitmapRep = NSBitmapImageRep.alloc.initWithFocusedViewRect([0,0,@picture.image.size.width, @picture.image.size.height])
    		@picture.image.unlockFocus
    	end
    	
    	# aight! save for later use.
    	@inputImage = CIImage.alloc.initWithBitmapImageRep(bitmapRep)
    	@oldPictureData = @pictureData
    	
        puts "* returning InputImage: " + (Time.now - starttime).to_s
    	return @inputImage
    end
end

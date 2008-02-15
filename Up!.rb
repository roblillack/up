#
#  Up!.rb
#  Up!
#
#  Created by Robert Lillack on 09.12.07.
#
#  ©2007 burningsoda.com
#        All rights reserved.
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
               :blogAccountSelector
	attr_accessor :settingsShown, :filePath

    # original picture
    attr_accessor :pictureData
    # max width or height in pixels -- bound to a slider
    attr_accessor :maxSize
    
    ib_action :windowShouldClose do |sender|
        NSApp.stop(self)
        true
    end
	
	ib_action :showSettings
	def showSettings(sender)
		OSX::NSApp.beginSheet_modalForWindow_modalDelegate_didEndSelector_contextInfo_(@settingsPanel, @mainWindow, self, nil, nil)
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
        @maxSize = 400
	end
    
    def awakeFromNib
        puts 'I\'m awake now.'
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
		@progress.stopAnimation(self)
        alert.release
    end
    
    ib_action :uploadPicture
	def uploadPicture(sender)
		puts "UploadPicture"
        
        return unless @pictureData
		@progress.startAnimation(self)
        
        @maxSize = @maxSize.to_i
                
        # convert picture
        #inputImage = OSX::CIImage.imageWithContentsOfURL(@pictureURL)
        inputImage = OSX::CIImage.imageWithData(@pictureData)
        oldWidth = OSX::CGRectGetWidth(inputImage.extent)
        oldHeight = OSX::CGRectGetHeight(inputImage.extent)
        if oldWidth > oldHeight then
            newWidth = @maxSize
            newHeight = (@maxSize * oldHeight / oldWidth).floor
            scaleFactor = (@maxSize + 4) / oldWidth
        else 
            newHeight = @maxSize
            newWidth = (@maxSize * oldWidth / oldHeight).floor
            scaleFactor = (@maxSize + 4) / oldHeight
        end
        
        puts "max. Size: #{@maxSize}"
        puts "actual Size: #{oldWidth}x#{oldHeight}"
        puts "resize factor: #{scaleFactor}"
        puts "new Size: #{scaleFactor * oldWidth}x#{scaleFactor * oldHeight}"
        puts "predicted new size: #{newWidth}x#{newHeight}"
        
        scaleFilter = OSX::CIFilter.filterWithName("CILanczosScaleTransform")
        scaleFilter.setDefaults()
        scaleFilter.setValue_forKey(inputImage, "inputImage")
        scaleFilter.setValue_forKey(OSX::NSNumber.numberWithDouble(scaleFactor), "inputScale")
        
        sharpenFilter = OSX::CIFilter.filterWithName("CISharpenLuminance")
        sharpenFilter.setDefaults()
        sharpenFilter.setValue_forKey(OSX::NSNumber.numberWithFloat(1.0), "inputSharpness")
        sharpenFilter.setValue_forKey(scaleFilter.valueForKey("outputImage"), "inputImage")

        contrastFilter = OSX::CIFilter.filterWithName("CIColorControls")
        contrastFilter.setDefaults()
        contrastFilter.setValue_forKey(OSX::NSNumber.numberWithFloat(1.05), "inputContrast")
        contrastFilter.setValue_forKey(sharpenFilter.valueForKey("outputImage"), "inputImage")
        
        outputImage = contrastFilter.valueForKey("outputImage")
        outputImage = outputImage.imageByCroppingToRect(CGRectMake(2, 2, newWidth, newHeight))
        newWidth = OSX::CGRectGetWidth(outputImage.extent)
        newHeight = OSX::CGRectGetHeight(outputImage.extent)
        puts "real new Size: #{newWidth}x#{newHeight}"
        
        jpegImage = OSX::NSBitmapImageRep.alloc.initWithCIImage(outputImage)
        outputData = jpegImage.representationUsingType_properties(OSX::NSJPEGFileType,
                                                                  {OSX::NSImageCompressionFactor => OSX::NSNumber.numberWithFloat(0.9)})

        selected_nsdict = @blogConfigurationController.arrangedObjects.to_a[@blogAccountSelector.indexOfSelectedItem]
        
        # pack up all the necessary data for the worker thread
        work = {
            :url => selected_nsdict.objectForKey('url').to_s,
            :blogid => selected_nsdict.objectForKey('active_id').to_s,
            :username => selected_nsdict.objectForKey('username').to_s,
            :password => selected_nsdict.objectForKey('password').to_s,
            :pictureData => outputData.rubyString
        }
        # and start it
        @workerthread = Thread.new(work) {|w| doUploadWork(w)}
        
        # now, go check if it finished every 500ms
        # count the checks: after 60s, we abort the upload
        @workerchecks = 120
        OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(0.5, self, "checkUploadState:", nil, true)
    end
    
    def checkUploadState(timer)
        if @workerchecks <= 0 then
            timer.invalidate
        else
            @workerchecks = @workerchecks - 1
        end
        
        return if @workerthread.alive?
        
        timer.invalidate
        result = @workerthread.value

		alert = OSX::NSAlert.alloc.init
		alert.addButtonWithTitle("OK")
        if result.key? 'error' then
            alert.setMessageText('Error uploading file.')
            alert.setInformativeText(result['error'])
        elsif not result.key? 'url' then
            alert.setMessageText('Error uploading file.')
            alert.setInformativeText('No URL in server response.')
        else
            alert.setMessageText('File successfully uploaded.')
            alert.setInformativeText('URL: ' + result['url'])
        end
		alert.beginSheetModalForWindow_modalDelegate_didEndSelector_contextInfo(@mainWindow, self, "alertDidEnd:returnCode:contextInfo:", nil)
	end
    
    def doUploadWork(work)
        begin
            client = XMLRPC::Client.new2(work[:url])
            return client.call('metaWeblog.newMediaObject', work[:blogid], work[:username], work[:password],
                               {'type' => 'image/jpeg', 'bits' => XMLRPC::Base64.new(work[:pictureData])})
        rescue Exception => e
            return { 'error' => e.message }
        end
    end
end

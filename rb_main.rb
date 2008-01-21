#
#  rb_main.rb
#  MediaUpload
#
#  Created by Robert Lillack on 09.12.07.
#  Copyright (c) 2007 burningsoda.com. All rights reserved.
#

require 'osx/cocoa'
include OSX
OSX.require_framework 'QuartzCore'

def rb_main_init
  path = OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
  rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
  rbfiles -= [ File.basename(__FILE__) ]
  rbfiles.each do |path|
    require( File.basename(path) )
  end
end

if $0 == __FILE__ then
  rb_main_init
  OSX.NSApplicationMain(0, nil)
end

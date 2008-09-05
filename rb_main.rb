framework 'Cocoa'
framework 'QuartzCore'

def rb_main_init
  path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
  rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
  rbfiles -= [ File.basename(__FILE__) ]
  rbfiles.each do |path|
    require( File.basename(path) )
  end
end

if $0 == __FILE__ then
  rb_main_init
  NSApplication.sharedApplication.activateIgnoringOtherApps(true)
  NSApplicationMain(0, nil)
end

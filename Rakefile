# -*- mode:ruby; indent-tabs-mode:nil; coding:utf-8 -*-
# vim:ts=2:sw=2:expandtab:
require 'erb'
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'pathname'

# Application own Settings
APPNAME               = "Up!"
CLEANNAME             = "up"
TARGET                = "#{APPNAME}.app"
APPVERSION            = `git tag -l '*.*' | sort -gr | head -n 1`.strip
APPBUILD              = `git log --pretty=oneline | wc -l`[/\d+/]
DEFAULT_TARGET        = APPNAME
DEFAULT_CONFIGURATION = 'Release'
RELEASE_CONFIGURATION = 'Release'

# Tasks
task :default => [:rundebug]

desc "Build the DEBUG configuration and run it, showing standard error output here."
task :rundebug => ["xcode:build:#{DEFAULT_TARGET}:Debug"] do
  sh %{"build/Debug/#{TARGET}/Contents/MacOS/#{APPNAME}"}
end


desc "Build the default and run it."
task :run => [:build] do
  sh %{open "build/Release/#{APPNAME}.app"}
end

desc 'Build the default target using the default configuration'
task :build => ["xcode:build:#{DEFAULT_TARGET}:#{DEFAULT_CONFIGURATION}"]

desc 'Deep clean of everything'
task :clean do
  #puts %x{ xcodebuild -alltargets clean }
  rm_rf "build"
end

desc "Add files to Xcode project"
task :add do |t|
 files = ARGV[1..-1]
 project = %x{ xcodebuild -list }[/Information about project "([^"]+)":/, 1]
 files << "#{project}.xcodeproj"
 exec("rubycocoa", "add", *files)
end

desc "Create ruby skelton and add to Xcode project"
task :create do |t|
 args = ARGV[1..-1]
 if system("rubycocoa", "create", *args)
   project = %x{ xcodebuild -list }[/Information about project "([^"]+)":/, 1]
   exec("rubycocoa", "add", args.last + ".rb", "#{project}.xcodeproj")
 end
end

desc "Update nib with ruby file"
task :update do |t|
 args = ARGV[1..-1]
 args.unshift("English.lproj/MainMenu.nib")
 exec("rubycocoa", "update", *args)
end

desc "Processes *.erb files"
rule(/.[^eE][^rR][^bB]$/ => [proc {|n| n+'.erb'}]) do |t|
    print "ERB: #{t.source} => #{t.name} … "
	open(t.name, 'w').write(ERB.new(open(t.source).read).result(binding))
	puts "done"
end

desc "Create a disk image"
task :dmg => ["xcode:build:#{DEFAULT_TARGET}:#{RELEASE_CONFIGURATION}"] do
	rm_rf "#{CLEANNAME}-#{APPVERSION}.dmg"
	sh %{hdiutil create -volname '#{APPNAME} #{APPVERSION}' -srcfolder "build/#{RELEASE_CONFIGURATION}/#{TARGET}" "#{CLEANNAME}-#{APPVERSION}.dmg"}
end

desc 'Make Localized nib from English.lproj and Lang.lproj/nib.strings'
rule(/.nib$/ => [proc {|tn| File.dirname(tn) + '/nib.strings' }]) do |t|
  p t.name
  lproj = File.dirname(t.name)
  target = File.basename(t.name)
  rm_rf t.name
  sh %{
  nibtool -d #{lproj}/nib.strings -w #{t.name} English.lproj/#{target}
  }
end

# [Rubycocoa-devel 906] dynamically xcode rake tasks
# [Rubycocoa-devel 907]
#
def xcode_targets
  out = %x{ xcodebuild -list }
  out.scan(/.*Targets:\s+(.*)Build Configurations:.*/m)

  targets = []
  $1.each_line do |l|
    l = l.strip.sub(' (Active)', '')
    targets << l unless l.nil? or l.empty?
  end
  targets
end

def xcode_configurations
  out = %x{ xcodebuild -list }
  out.scan(/.*Build Configurations:\s+(.*)If no build configuration.*/m)

  configurations = []
  $1.each_line do |l|
    l = l.strip.sub(' (Active)', '')
    configurations << l unless l.nil? or l.empty?
  end
  configurations
end

namespace :xcode do
 needed = []
 targets = xcode_targets
 configs = xcode_configurations

 %w{build clean}.each do |action|
   namespace "#{action}" do

     targets.each do |target|
       desc "#{action} #{target}"
       task "#{target}" => needed do |t|
         puts %x{ xcodebuild -target '#{target}' #{action} }
       end

       # alias the task above using a massaged name
       massaged_target = target.downcase.gsub(/[\s*|\-]/, '_')
       task "#{massaged_target}" => "xcode:#{action}:#{target}"


       namespace "#{target}" do
         configs.each do |config|
           desc "#{action} #{target} #{config}"
           task "#{config}" => needed do |t|
             sh %{xcodebuild -target '#{target}' -configuration '#{config}' #{action}}
           end
         end
       end

       # namespace+task aliases of the above using massaged names
       namespace "#{massaged_target}" do
         configs.each { |conf| task "#{conf.downcase.gsub(/[\s*|\-]/, '_')}" => "xcode:#{action}:#{target}:#{conf}" }
       end

     end

   end
 end
end


if ["update", "add", "create"].include? ARGV[0]
  # dupe rake
  ARGV.map! {|a| a.sub(/^\+/, "-") }
  Rake.application[ARGV[0].to_sym].invoke
  exit # will not reach
end

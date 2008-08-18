#
#  rb_main.rb
#  iWassr
#
#  Created by Keiji Yoshimi on 08/07/05.
#  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
#

require 'osx/cocoa'

begin
  require 'osx/hotkey'
rescue LoadError => e
  $LOAD_PATH.unshift(File.expand_path(File.join( File.dirname(__FILE__), 'vendor', 'osxhotkey', 'lib')))
  $LOAD_PATH.unshift(File.expand_path(File.join( File.dirname(__FILE__), 'vendor', 'osxhotkey', 'ext')))
  require 'osx/hotkey'
end

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
  OSX::NSApplicationWithHotKey.sharedApplication
  OSX.NSApplicationMain(0, nil)
end

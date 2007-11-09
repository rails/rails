ENV['LOG_NAME'] = 'spec'
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'vendor', 'rspec', 'lib')
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
require 'active_model'
begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  require 'spec'
end

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
  # you do not know the ways of ruby-debug yet, what a shame
end
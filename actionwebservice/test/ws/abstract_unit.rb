$:.unshift(File.dirname(File.dirname(__FILE__)) + '/../lib')
$:.unshift(File.dirname(File.dirname(__FILE__)) + '/../lib/action_web_service/vendor')
puts $:.inspect
require 'test/unit'
require 'ws'
begin
  require 'active_record'
rescue LoadError
  begin
    require 'rubygems'
    require_gem 'activerecord', '>= 1.6.0'
  rescue LoadError
  end
end

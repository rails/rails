activesupport_path = "#{File.dirname(__FILE__)}/../../../activesupport/lib"
$:.unshift(activesupport_path) if File.directory?(activesupport_path)
require 'active_support/inflector'

require 'rubygems'
require 'test/unit'

gem 'mocha', '>= 0.9.5'
require 'mocha'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
$:.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"
require 'active_resource'
require 'active_resource/http_mock'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

def uses_gem(gem_name, test_name, version = '> 0')
  gem gem_name.to_s, version
  require gem_name.to_s
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install #{gem_name}` and try again."
end

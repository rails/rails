require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'
require 'active_resource/http_mock'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

def uses_gem(gem_name, test_name, version = '> 0')
  require 'rubygems'
  gem gem_name.to_s, version
  require gem_name.to_s
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install #{gem_name}` and try again."
end

# Wrap tests that use Mocha and skip if unavailable.
unless defined? uses_mocha
  def uses_mocha(test_name, &block)
    uses_gem('mocha', test_name, '>= 0.5.5', &block)
  end
end

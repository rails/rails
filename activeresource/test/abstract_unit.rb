require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'
require 'active_resource/http_mock'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

# Wrap tests that use Mocha and skip if unavailable.
def uses_mocha(test_name)
  unless Object.const_defined?(:Mocha)
    require 'mocha'
    require 'stubba'
  end
  yield
rescue LoadError => load_error
  raise unless load_error.message =~ /mocha/i
  $stderr.puts "Skipping #{test_name} tests. `gem install mocha` and try again."
end
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"

require 'test/unit'
require 'stringio'
require 'active_support'

# Wrap tests that use Mocha and skip if unavailable.
def uses_mocha(test_name)
  require 'rubygems'
  gem 'mocha', '>= 0.5.5'
  require 'mocha'
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install mocha` and try again."
end

if defined?(RAILS_ROOT)
  RAILS_ROOT.replace File.dirname(__FILE__)
else
  RAILS_ROOT = File.dirname(__FILE__)
end

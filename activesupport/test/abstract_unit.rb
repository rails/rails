require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
$:.unshift File.dirname(__FILE__)
require 'active_support'

# Wrap tests that use Mocha and skip if unavailable.
unless defined? uses_mocha
  def uses_mocha(test_name)
    require 'rubygems'
    gem 'mocha', '>= 0.5.5'
    require 'mocha'
    yield
  rescue LoadError
    $stderr.puts "Skipping #{test_name} tests. `gem install mocha` and try again."
  end
end

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

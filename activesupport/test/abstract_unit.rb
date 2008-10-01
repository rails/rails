# encoding: utf-8

require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
$:.unshift File.dirname(__FILE__)
require 'active_support'

if RUBY_VERSION < '1.9'
  $KCODE = 'UTF8'
end

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

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

def with_kcode(code)
  if RUBY_VERSION < '1.9'
    begin
      old_kcode, $KCODE = $KCODE, code
      yield
    ensure
      $KCODE = old_kcode
    end
  else
    yield
  end
end
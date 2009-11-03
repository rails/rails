ORIG_ARGV = ARGV.dup
root = File.expand_path('../../..', __FILE__)
begin
  require "#{root}/vendor/gems/environment"
rescue LoadError
  $:.unshift("#{root}/activesupport/lib")
  $:.unshift("#{root}/activerecord/lib")
end


require 'test/unit'

begin
  require 'mocha'
rescue LoadError
  $stderr.puts 'Loading rubygems'
  require 'rubygems'
  require 'mocha'
end

ENV['NO_RELOAD'] = '1'
require 'active_support'
require 'active_support/test_case'

# Include shims until we get off 1.8.6
require 'active_support/ruby/shim'

def uses_memcached(test_name)
  require 'memcache'
  begin
    MemCache.new('localhost').stats
    yield
  rescue MemCache::MemCacheError
    $stderr.puts "Skipping #{test_name} tests. Start memcached and try again."
  end
end

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

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

if RUBY_VERSION < '1.9'
  $KCODE = 'UTF8'
end

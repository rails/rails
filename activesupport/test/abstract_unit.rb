ORIG_ARGV = ARGV.dup

require 'rubygems'
require 'test/unit'

ENV['NO_RELOAD'] = '1'
$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_support'
require 'active_support/test_case'

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

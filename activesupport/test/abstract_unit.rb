ORIG_ARGV = ARGV.dup

begin
  old, $VERBOSE = $VERBOSE, nil
  require File.expand_path('../../../load_paths', __FILE__)
ensure
  $VERBOSE = old
end

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'active_support/core_ext/kernel/reporting'

require 'active_support/core_ext/string/encoding'
if "ruby".encoding_aware?
  # These are the normal settings that will be set up by Railties
  # TODO: Have these tests support other combinations of these values
  silence_warnings do
    Encoding.default_internal = "UTF-8"
    Encoding.default_external = "UTF-8"
  end
end

require 'test/unit'
require 'empty_bool'

silence_warnings { require 'mocha/setup' }

ENV['NO_RELOAD'] = '1'
require 'active_support'

# Include shims until we get off 1.8.6
require 'active_support/ruby/shim' if RUBY_VERSION < '1.8.7'

def uses_memcached(test_name)
  require 'memcache'
  begin
    MemCache.new('localhost:11211').stats
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

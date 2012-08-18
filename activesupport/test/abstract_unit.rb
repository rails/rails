ORIG_ARGV = ARGV.dup

begin
  old, $VERBOSE = $VERBOSE, nil
  require File.expand_path('../../../load_paths', __FILE__)
ensure
  $VERBOSE = old
end

require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/string/encoding'

silence_warnings do
  Encoding.default_internal = "UTF-8"
  Encoding.default_external = "UTF-8"
end

require 'minitest/autorun'
require 'empty_bool'

ENV['NO_RELOAD'] = '1'
require 'active_support'

def uses_memcached(test_name)
  require 'dalli'
  begin
    Dalli::Client.new('localhost:11211').stats
    yield
  rescue Dalli::DalliError
    $stderr.puts "Skipping #{test_name} tests. Start memcached and try again."
  end
end

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

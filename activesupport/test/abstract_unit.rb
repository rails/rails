ORIG_ARGV = ARGV.dup

begin
  old, $VERBOSE = $VERBOSE, nil
  require File.expand_path('../../../load_paths', __FILE__)
ensure
  $VERBOSE = old
end

require 'active_support/core_ext/kernel/reporting'

silence_warnings do
  Encoding.default_internal = "UTF-8"
  Encoding.default_external = "UTF-8"
end

require 'active_support/testing/autorun'

ENV['NO_RELOAD'] = '1'
require 'active_support'

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Skips the current run on Rubinius using Minitest::Assertions#skip
def rubinius_skip(message = '')
  skip message if RUBY_ENGINE == 'rbx'
end

# Skips the current run on JRuby using Minitest::Assertions#skip
def jruby_skip(message = '')
  skip message if defined?(JRUBY_VERSION)
end

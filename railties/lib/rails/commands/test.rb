require "rails/test_unit/minitest_plugin"
require "rails/test_unit/line_filtering"

if defined?(ENGINE_ROOT)
  $LOAD_PATH << File.expand_path("test", ENGINE_ROOT)
else
  $LOAD_PATH << File.expand_path("../../test", APP_PATH)
end

# Add test line filtering support for running test by line number
# via the command line.
ActiveSupport::TestCase.extend Rails::LineFiltering

Minitest.run_via[:rails] = true

require "active_support/testing/autorun"

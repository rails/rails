require "rails/test_unit/minitest_plugin"

if defined?(ENGINE_ROOT)
  $LOAD_PATH << File.expand_path("test", ENGINE_ROOT)
else
  $LOAD_PATH << File.expand_path("../../test", APP_PATH)
end

Minitest.run_via[:rails] = true

require "active_support/testing/autorun"

require "rails/test_unit/minitest_plugin"
require "active_support/testing/autorun"

if defined?(ENGINE_ROOT)
  $LOAD_PATH << File.expand_path("test", ENGINE_ROOT)
else
  $LOAD_PATH << File.expand_path("../../test", APP_PATH)
end

require "rails/test_unit/minitest_plugin"

if defined?(ENGINE_ROOT)
  $LOAD_PATH << File.expand_path("test", ENGINE_ROOT)
else
  $LOAD_PATH << File.expand_path("../../test", APP_PATH)
end

result = Minitest.run(ARGV)
Minitest.class_variable_get(:@@after_run).reverse_each(&:call)
exit result

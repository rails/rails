require "rails/test_unit/runner"

if defined?(ENGINE_ROOT)
  $LOAD_PATH << File.expand_path("test", ENGINE_ROOT)
else
  $LOAD_PATH << File.expand_path("../../test", APP_PATH)
end

Rails::TestUnit::Runner.parse_options(ARGV)
Rails::TestUnit::Runner.run(ARGV)

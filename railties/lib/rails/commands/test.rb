require "rails/test_unit/runner"

$: << File.expand_path("../../test", APP_PATH)

Rails::TestRunner.run(ARGV)

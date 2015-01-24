ENV["RAILS_ENV"] = "test"
require "rails/test_unit/runner"

options = Rails::TestRunner::Options.parse(ARGV)
$: << File.expand_path("../../test", APP_PATH)

Rails::TestRunner.new(options).run

ENV["RAILS_ENV"] = "test"
require "rails/test_unit/runner"
require "rails/test_unit/reporter"

options = Rails::TestRunner::Options.parse(ARGV)
$: << File.expand_path("../../test", APP_PATH)

$runner = Rails::TestRunner.new(options)

def Minitest.plugin_rails_init(options)
  self.reporter << Rails::TestUnitReporter.new(options[:io], options)
  if method = $runner.find_method
    options[:filter] = "/^(#{method})$/"
  end
end
Minitest.extensions << 'rails'

# Config Rails backtrace in tests.
$runner.run

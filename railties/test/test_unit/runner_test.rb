require 'abstract_unit'
require 'rails/test_unit/runner'

class TestUnitTestRunnerTest < ActiveSupport::TestCase
  setup do
    @options = Rails::TestRunner::Options
  end

  test "shows the filtered backtrace by default" do
    options = @options.parse([])
    assert_not options[:backtrace]
  end

  test "has --backtrace (-b) option to show the full backtrace" do
    options = @options.parse(["-b"])
    assert options[:backtrace]

    options = @options.parse(["--backtrace"])
    assert options[:backtrace]
  end
end

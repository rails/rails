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

  test "parse the filename and line" do
    options = @options.parse(["foobar.rb:20"])
    assert_equal File.expand_path("foobar.rb"), options[:filename]
    assert_equal 20, options[:line]

    options = @options.parse(["foobar.rb:"])
    assert_equal File.expand_path("foobar.rb"), options[:filename]
    assert_nil options[:line]

    options = @options.parse(["foobar.rb"])
    assert_equal File.expand_path("foobar.rb"), options[:filename]
    assert_nil options[:line]
  end

  test "find_method on same file" do
    options = @options.parse(["#{__FILE__}:#{__LINE__}"])
    runner = Rails::TestRunner.new(options)
    assert_equal "test_find_method_on_same_file", runner.find_method
  end

  test "find_method on a different file" do
    options = @options.parse(["foobar.rb:#{__LINE__}"])
    runner = Rails::TestRunner.new(options)
    assert_nil runner.find_method
  end
end

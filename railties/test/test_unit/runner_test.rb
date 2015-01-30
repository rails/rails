require 'abstract_unit'
require 'env_helpers'
require 'rails/test_unit/runner'

class TestUnitTestRunnerTest < ActiveSupport::TestCase
  include EnvHelpers

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

  test "show full backtrace using BACKTRACE environment variable" do
    switch_env "BACKTRACE", "true" do
      options = @options.parse([])
      assert options[:backtrace]
    end
  end

  test "tests run in the test environment by default" do
    options = @options.parse([])
    assert_equal "test", options[:environment]
  end

  test "can run in a specific environment" do
    options = @options.parse(["-e development"])
    assert_equal "development", options[:environment]
  end

  test "parse the filename and line" do
    file = "test/test_unit/runner_test.rb"
    absolute_file = __FILE__
    options = @options.parse(["#{file}:20"])
    assert_equal absolute_file, options[:filename]
    assert_equal 20, options[:line]

    options = @options.parse(["#{file}:"])
    assert_equal [absolute_file], options[:patterns]
    assert_nil options[:line]

    options = @options.parse([file])
    assert_equal [absolute_file], options[:patterns]
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

  test "run all tests in a directory" do
    options = @options.parse([__dir__])

    assert_equal ["#{__dir__}/**/*_test.rb"], options[:patterns]
    assert_nil options[:filename]
    assert_nil options[:line]
  end

  test "run multiple folders" do
    application_dir = File.expand_path("#{__dir__}/../application")

    options = @options.parse([__dir__, application_dir])

    assert_equal ["#{__dir__}/**/*_test.rb", "#{application_dir}/**/*_test.rb"], options[:patterns]
    assert_nil options[:filename]
    assert_nil options[:line]

    runner = Rails::TestRunner.new(options)
    assert runner.test_files.size > 0
  end

  test "run multiple files and run one file by line" do
    line = __LINE__
    options = @options.parse([__dir__, "#{__FILE__}:#{line}"])

    assert_equal ["#{__dir__}/**/*_test.rb"], options[:patterns]
    assert_equal __FILE__, options[:filename]
    assert_equal line, options[:line]

    runner = Rails::TestRunner.new(options)
    assert_equal [__FILE__], runner.test_files, 'Only returns the file that running by line'
  end

  test "running multiple files passing line number" do
    line = __LINE__
    options = @options.parse(["foobar.rb:8", "#{__FILE__}:#{line}"])

    assert_equal __FILE__, options[:filename], 'Returns the last file'
    assert_equal line, options[:line]
  end
end

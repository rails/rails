require 'abstract_unit'

# Does awesome
if ENV['CHILD']
  class ChildIsolationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def self.setup
      File.open(File.join(File.dirname(__FILE__), "fixtures", "isolation_test"), "a") do |f|
        f.puts "hello"
      end
    end

    def setup
      @instance = "HELLO"
    end

    def teardown
      raise if @boom
    end

    test "runs the test" do
      assert true
    end

    test "captures errors" do
      raise
    end

    test "captures failures" do
      assert false
    end

    test "first runs in isolation" do
      assert_nil $x
      $x = 1
    end

    test "second runs in isolation" do
      assert_nil $x
      $x = 2
    end

    test "runs with slow tests" do
      sleep 0.3
      assert true
      sleep 0.2
    end

    test "runs setup" do
      assert "HELLO", @instance
    end

    test "runs teardown" do
      @boom = true
    end

    test "resets requires one" do
      assert !defined?(OmgOmg)
      assert_equal 0, $LOADED_FEATURES.grep(/fixtures\/omgomg/).size
      require File.expand_path(File.join(File.dirname(__FILE__), "fixtures", "omgomg"))
    end

    test "resets requires two" do
      assert !defined?(OmgOmg)
      assert_equal 0, $LOADED_FEATURES.grep(/fixtures\/omgomg/).size
      require File.expand_path(File.join(File.dirname(__FILE__), "fixtures", "omgomg"))
    end
  end
else
  class ParentIsolationTest < ActiveSupport::TestCase

    File.open(File.join(File.dirname(__FILE__), "fixtures", "isolation_test"), "w") {}

    ENV["CHILD"] = "1"
    OUTPUT = `#{Gem.ruby} -I#{File.dirname(__FILE__)} "#{File.expand_path(__FILE__)}" -v`
    ENV.delete("CHILD")

    def setup
      # Extract the results
      @results = {}
      OUTPUT[/Started\n\s*(.*)\s*\nFinished/mi, 1].split(/\s*\n\s*/).each do |result|
        result =~ %r'^(\w+)\(\w+\):\s*(\.|E|F)$'
        @results[$1] = { 'E' => :error, '.' => :success, 'F' => :failure }[$2]
      end

      # Extract the backtraces
      @backtraces = {}
      OUTPUT.scan(/^\s*\d+\).*?\n\n/m).each do |backtrace|
        # \n  1) Error:\ntest_captures_errors(ChildIsolationTest):
        backtrace =~ %r'\s*\d+\)\s*(Error|Failure):\n(\w+)'i
        @backtraces[$2] = { :type => $1, :output => backtrace }
      end
    end

    def assert_failing(name)
      assert_equal :failure, @results[name.to_s], "Test #{name} did not fail"
    end

    def assert_passing(name)
      assert_equal :success, @results[name.to_s], "Test #{name} did not pass"
    end

    def assert_erroring(name)
      assert_equal :error, @results[name.to_s], "Test #{name} did not error"
    end

    test "has all tests" do
      assert_equal 10, @results.length
    end

    test "passing tests are still reported" do
      assert_passing :test_runs_the_test
      assert_passing :test_runs_with_slow_tests
    end

    test "resets global variables" do
      assert_passing :test_first_runs_in_isolation
      assert_passing :test_second_runs_in_isolation
    end

    test "resets requires" do
      assert_passing :test_resets_requires_one
      assert_passing :test_resets_requires_two
    end

    test "erroring tests are still reported" do
      assert_erroring :test_captures_errors
    end

    test "runs setup and teardown methods" do
      assert_passing :test_runs_setup
      assert_erroring :test_runs_teardown
    end

    test "correct tests fail" do
      assert_failing :test_captures_failures
    end

    test "backtrace is printed for errors" do
      assert_equal 'Error', @backtraces["test_captures_errors"][:type]
      assert_match %r{isolation_test.rb:\d+:in `test_captures_errors'}, @backtraces["test_captures_errors"][:output]
    end

    test "backtrace is printed for failures" do
      assert_equal 'Failure', @backtraces["test_captures_failures"][:type]
      assert_match %r{isolation_test.rb:\d+:in `test_captures_failures'}, @backtraces["test_captures_failures"][:output]
    end

    test "self.setup is run only once" do
      text = File.read(File.join(File.dirname(__FILE__), "fixtures", "isolation_test"))
      assert_equal "hello\n", text
    end

  end
end
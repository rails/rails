# frozen_string_literal: true

require "abstract_unit"
require "rails/test_unit/reporter"
require "minitest/mock"

class TestUnitReporterTest < ActiveSupport::TestCase
  class ExampleTest < Minitest::Test
    def woot; end
  end

  setup do
    @output = StringIO.new
    @reporter = Rails::TestUnitReporter.new @output, output_inline: true
  end

  test "prints rerun snippet to run a single failed test" do
    record(failed_test)
    @reporter.report

    assert_match %r{^#{test_run_command_regex} .*test/test_unit/reporter_test\.rb:\d+$}, @output.string
    assert_rerun_snippet_count 1
  end

  test "prints rerun snippet for every failed test" do
    record(failed_test)
    record(failed_test)
    record(failed_test)
    @reporter.report

    assert_rerun_snippet_count 3
  end

  test "does not print snippet for successful and skipped tests" do
    record(passing_test)
    record(skipped_test)
    @reporter.report
    assert_no_match "Failed tests:", @output.string
    assert_rerun_snippet_count 0
  end

  test "prints rerun snippet for skipped tests if run in verbose mode" do
    @reporter = Rails::TestUnitReporter.new @output, verbose: true
    record(skipped_test)
    @reporter.report

    assert_rerun_snippet_count 1
  end

  test "allows to customize the executable in the rerun snippet" do
    original_executable = Rails::TestUnitReporter.executable
    begin
      Rails::TestUnitReporter.executable = "bin/test"
      record(failed_test)
      @reporter.report

      assert_match %r{^bin/test .*test/test_unit/reporter_test\.rb:\d+$}, @output.string
    ensure
      Rails::TestUnitReporter.executable = original_executable
    end
  end

  test "outputs failures inline" do
    record(failed_test)
    @reporter.report

    expect = %r{\AF\n\nFailure:\nTestUnitReporterTest::ExampleTest#woot \[[^\]]+\]:\nboo\n\n#{test_run_command_regex} test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test "outputs errors inline" do
    record(errored_test)
    @reporter.report

    expect = %r{\AE\n\nError:\nTestUnitReporterTest::ExampleTest#woot:\nArgumentError: wups\n    some_test.rb:4\n\n#{test_run_command_regex} .*test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test "outputs skipped tests inline if verbose" do
    @reporter = Rails::TestUnitReporter.new @output, verbose: true, output_inline: true
    record(skipped_test)
    @reporter.report

    expect = %r{\ATestUnitReporterTest::ExampleTest#woot = 10\.00 s = S\n\n\nSkipped:\nTestUnitReporterTest::ExampleTest#woot \[[^\]]+\]:\nskipchurches, misstemples\n\n#{test_run_command_regex} test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test "does not output rerun snippets after run" do
    record(failed_test)
    @reporter.report

    assert_no_match "Failed tests:", @output.string
  end

  test "fail fast interrupts run on failure" do
    @reporter = Rails::TestUnitReporter.new @output, fail_fast: true
    interrupt_raised = false

    # Minitest passes through Interrupt, catch it manually.
    begin
      record(failed_test)
    rescue Interrupt
      interrupt_raised = true
    ensure
      assert interrupt_raised, "Expected Interrupt to be raised."
    end
  end

  test "fail fast interrupts run on error" do
    @reporter = Rails::TestUnitReporter.new @output, fail_fast: true
    interrupt_raised = false

    # Minitest passes through Interrupt, catch it manually.
    begin
      record(errored_test)
    rescue Interrupt
      interrupt_raised = true
    ensure
      assert interrupt_raised, "Expected Interrupt to be raised."
    end
  end

  test "fail fast does not interrupt run skips" do
    @reporter = Rails::TestUnitReporter.new @output, fail_fast: true

    record(skipped_test)
    assert_no_match "Failed tests:", @output.string
  end

  test "outputs colored passing results" do
    @output.stub(:tty?, true) do
      @reporter = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      record(passing_test)

      expect = %r{\e\[32m\.\e\[0m}
      assert_match expect, @output.string
    end
  end

  test "outputs colored skipped results" do
    @output.stub(:tty?, true) do
      @reporter = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      record(skipped_test)

      expect = %r{\e\[33mS\e\[0m}
      assert_match expect, @output.string
    end
  end

  test "outputs colored failed results" do
    @output.stub(:tty?, true) do
      @reporter = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      record(failed_test)

      expected = %r{\e\[31mF\e\[0m\n\n\e\[31mFailure:\nTestUnitReporterTest::ExampleTest#woot \[test/test_unit/reporter_test.rb:\d+\]:\nboo\n\e\[0m\n\n#{test_run_command_regex} .*test/test_unit/reporter_test.rb:\d+\n\n}
      assert_match expected, @output.string
    end
  end

  test "outputs colored error results" do
    @output.stub(:tty?, true) do
      @reporter = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      record(errored_test)

      expected = %r{\e\[31mE\e\[0m\n\n\e\[31mError:\nTestUnitReporterTest::ExampleTest#woot:\nArgumentError: wups\n    some_test.rb:4\n\e\[0m}
      assert_match expected, @output.string
    end
  end

  private
    def record(test_result)
      @reporter.prerecord(test_result.klass.constantize, test_result.name)
      @reporter.record(test_result)
    end

    def assert_rerun_snippet_count(snippet_count)
      assert_equal snippet_count, @output.string.scan(%r{^#{test_run_command_regex} }).size
    end

    def failed_test
      ft = Minitest::Result.from(ExampleTest.new(:woot))
      ft.failures << begin
                       raise Minitest::Assertion, "boo"
                     rescue Minitest::Assertion => e
                       e
                     end
      ft
    end

    def errored_test
      error = ArgumentError.new("wups")
      error.set_backtrace([ "some_test.rb:4" ])

      et = Minitest::Result.from(ExampleTest.new(:woot))
      et.failures << Minitest::UnexpectedError.new(error)
      et
    end

    def passing_test
      Minitest::Result.from(ExampleTest.new(:woot))
    end

    def skipped_test
      st = Minitest::Result.from(ExampleTest.new(:woot))
      st.failures << begin
                       raise Minitest::Skip, "skipchurches, misstemples"
                     rescue Minitest::Assertion => e
                       e
                     end
      st.time = 10
      st
    end

    def test_run_command_regex
      %r{bin/rails test|bin/test}
    end
end

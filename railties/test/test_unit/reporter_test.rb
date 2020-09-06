# frozen_string_literal: true

require 'abstract_unit'
require 'rails/test_unit/reporter'
require 'minitest/mock'

class TestUnitReporterTest < ActiveSupport::TestCase
  class ExampleTest < Minitest::Test
    def woot; end
  end

  setup do
    @output = StringIO.new
    @reporter = Rails::TestUnitReporter.new @output, output_inline: true
  end

  test 'prints rerun snippet to run a single failed test' do
    @reporter.record(failed_test)
    @reporter.report

    assert_match %r{^rails test .*test/test_unit/reporter_test\.rb:\d+$}, @output.string
    assert_rerun_snippet_count 1
  end

  test 'prints rerun snippet for every failed test' do
    @reporter.record(failed_test)
    @reporter.record(failed_test)
    @reporter.record(failed_test)
    @reporter.report

    assert_rerun_snippet_count 3
  end

  test 'does not print snippet for successful and skipped tests' do
    @reporter.record(passing_test)
    @reporter.record(skipped_test)
    @reporter.report
    assert_no_match 'Failed tests:', @output.string
    assert_rerun_snippet_count 0
  end

  test 'prints rerun snippet for skipped tests if run in verbose mode' do
    verbose = Rails::TestUnitReporter.new @output, verbose: true
    verbose.record(skipped_test)
    verbose.report

    assert_rerun_snippet_count 1
  end

  test 'allows to customize the executable in the rerun snippet' do
    original_executable = Rails::TestUnitReporter.executable
    begin
      Rails::TestUnitReporter.executable = 'bin/test'
      @reporter.record(failed_test)
      @reporter.report

      assert_match %r{^bin/test .*test/test_unit/reporter_test\.rb:\d+$}, @output.string
    ensure
      Rails::TestUnitReporter.executable = original_executable
    end
  end

  test 'outputs failures inline' do
    @reporter.record(failed_test)
    @reporter.report

    expect = %r{\AF\n\nFailure:\nTestUnitReporterTest::ExampleTest#woot \[[^\]]+\]:\nboo\n\nrails test test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test 'outputs errors inline' do
    @reporter.record(errored_test)
    @reporter.report

    expect = %r{\AE\n\nError:\nTestUnitReporterTest::ExampleTest#woot:\nArgumentError: wups\n    some_test.rb:4\n\nrails test .*test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test 'outputs skipped tests inline if verbose' do
    verbose = Rails::TestUnitReporter.new @output, verbose: true, output_inline: true
    verbose.record(skipped_test)
    verbose.report

    expect = %r{\ATestUnitReporterTest::ExampleTest#woot = 10\.00 s = S\n\n\nSkipped:\nTestUnitReporterTest::ExampleTest#woot \[[^\]]+\]:\nskipchurches, misstemples\n\nrails test test/test_unit/reporter_test\.rb:\d+\n\n\z}
    assert_match expect, @output.string
  end

  test 'does not output rerun snippets after run' do
    @reporter.record(failed_test)
    @reporter.report

    assert_no_match 'Failed tests:', @output.string
  end

  test 'fail fast interrupts run on failure' do
    fail_fast = Rails::TestUnitReporter.new @output, fail_fast: true
    interrupt_raised = false

    # Minitest passes through Interrupt, catch it manually.
    begin
      fail_fast.record(failed_test)
    rescue Interrupt
      interrupt_raised = true
    ensure
      assert interrupt_raised, 'Expected Interrupt to be raised.'
    end
  end

  test 'fail fast interrupts run on error' do
    fail_fast = Rails::TestUnitReporter.new @output, fail_fast: true
    interrupt_raised = false

    # Minitest passes through Interrupt, catch it manually.
    begin
      fail_fast.record(errored_test)
    rescue Interrupt
      interrupt_raised = true
    ensure
      assert interrupt_raised, 'Expected Interrupt to be raised.'
    end
  end

  test 'fail fast does not interrupt run skips' do
    fail_fast = Rails::TestUnitReporter.new @output, fail_fast: true

    fail_fast.record(skipped_test)
    assert_no_match 'Failed tests:', @output.string
  end

  test 'outputs colored passing results' do
    @output.stub(:tty?, true) do
      colored = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      colored.record(passing_test)

      expect = %r{\e\[32m\.\e\[0m}
      assert_match expect, @output.string
    end
  end

  test 'outputs colored skipped results' do
    @output.stub(:tty?, true) do
      colored = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      colored.record(skipped_test)

      expect = %r{\e\[33mS\e\[0m}
      assert_match expect, @output.string
    end
  end

  test 'outputs colored failed results' do
    @output.stub(:tty?, true) do
      colored = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      colored.record(failed_test)

      expected = %r{\e\[31mF\e\[0m\n\n\e\[31mFailure:\nTestUnitReporterTest::ExampleTest#woot \[test/test_unit/reporter_test.rb:\d+\]:\nboo\n\e\[0m\n\nrails test .*test/test_unit/reporter_test.rb:\d+\n\n}
      assert_match expected, @output.string
    end
  end

  test 'outputs colored error results' do
    @output.stub(:tty?, true) do
      colored = Rails::TestUnitReporter.new @output, color: true, output_inline: true
      colored.record(errored_test)

      expected = %r{\e\[31mE\e\[0m\n\n\e\[31mError:\nTestUnitReporterTest::ExampleTest#woot:\nArgumentError: wups\n    some_test.rb:4\n\e\[0m}
      assert_match expected, @output.string
    end
  end

  private
    def assert_rerun_snippet_count(snippet_count)
      assert_equal snippet_count, @output.string.scan(%r{^rails test }).size
    end

    def failed_test
      ft = Minitest::Result.from(ExampleTest.new(:woot))
      ft.failures << begin
                       raise Minitest::Assertion, 'boo'
                     rescue Minitest::Assertion => e
                       e
                     end
      ft
    end

    def errored_test
      error = ArgumentError.new('wups')
      error.set_backtrace([ 'some_test.rb:4' ])

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
                       raise Minitest::Skip, 'skipchurches, misstemples'
                     rescue Minitest::Assertion => e
                       e
                     end
      st.time = 10
      st
    end
end

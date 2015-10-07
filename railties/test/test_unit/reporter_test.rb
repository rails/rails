require 'abstract_unit'
require 'rails/test_unit/reporter'

class TestUnitReporterTest < ActiveSupport::TestCase
  class ExampleTest < Minitest::Test
    def woot; end
  end

  setup do
    @output = StringIO.new
    @reporter = Rails::TestUnitReporter.new @output, output_inline: true
  end

  test "prints rerun snippet to run a single failed test" do
    @reporter.record(failed_test)
    @reporter.report

    assert_match %r{^bin/rails test .*test/test_unit/reporter_test.rb:6$}, @output.string
    assert_rerun_snippet_count 1
  end

  test "prints rerun snippet for every failed test" do
    @reporter.record(failed_test)
    @reporter.record(failed_test)
    @reporter.record(failed_test)
    @reporter.report

    assert_rerun_snippet_count 3
  end

  test "does not print snippet for successful and skipped tests" do
    @reporter.record(passing_test)
    @reporter.record(skipped_test)
    @reporter.report
    assert_no_match 'Failed tests:', @output.string
    assert_rerun_snippet_count 0
  end

  test "prints rerun snippet for skipped tests if run in verbose mode" do
    verbose = Rails::TestUnitReporter.new @output, verbose: true
    verbose.record(skipped_test)
    verbose.report

    assert_rerun_snippet_count 1
  end

  test "allows to customize the executable in the rerun snippet" do
    original_executable = Rails::TestUnitReporter.executable
    begin
      Rails::TestUnitReporter.executable = "bin/test"
      @reporter.record(failed_test)
      @reporter.report

      assert_match %r{^bin/test .*test/test_unit/reporter_test.rb:6$}, @output.string
    ensure
      Rails::TestUnitReporter.executable = original_executable
    end
  end

  test "outputs failures inline" do
    @reporter.record(failed_test)
    @reporter.report

    assert_match %r{\A\n\nboo\n\nbin/rails test .*test/test_unit/reporter_test.rb:6\n\n\z}, @output.string
  end

  test "outputs errors inline" do
    @reporter.record(errored_test)
    @reporter.report

    assert_match %r{\A\n\nArgumentError: wups\n    No backtrace\n\nbin/rails test .*test/test_unit/reporter_test.rb:6\n\n\z}, @output.string
  end

  test "outputs skipped tests inline if verbose" do
    verbose = Rails::TestUnitReporter.new @output, verbose: true, output_inline: true
    verbose.record(skipped_test)
    verbose.report

    assert_match %r{\A\n\nskipchurches, misstemples\n\nbin/rails test .*test/test_unit/reporter_test.rb:6\n\n\z}, @output.string
  end

  test "does not output rerun snippets after run" do
    @reporter.record(failed_test)
    @reporter.report

    assert_no_match 'Failed tests:', @output.string
  end

  test "fail fast interrupts run on failure" do
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

  test "fail fast does not interrupt run errors or skips" do
    fail_fast = Rails::TestUnitReporter.new @output, fail_fast: true

    fail_fast.record(errored_test)
    assert_no_match 'Failed tests:', @output.string

    fail_fast.record(skipped_test)
    assert_no_match 'Failed tests:', @output.string
  end

  private
  def assert_rerun_snippet_count(snippet_count)
    assert_equal snippet_count, @output.string.scan(%r{^bin/rails test }).size
  end

  def failed_test
    ft = ExampleTest.new(:woot)
    ft.failures << begin
                     raise Minitest::Assertion, "boo"
                   rescue Minitest::Assertion => e
                     e
                   end
    ft
  end

  def errored_test
    et = ExampleTest.new(:woot)
    et.failures << Minitest::UnexpectedError.new(ArgumentError.new("wups"))
    et
  end

  def passing_test
    ExampleTest.new(:woot)
  end

  def skipped_test
    st = ExampleTest.new(:woot)
    st.failures << begin
                     raise Minitest::Skip, "skipchurches, misstemples"
                   rescue Minitest::Assertion => e
                     e
                   end
    st
  end
end

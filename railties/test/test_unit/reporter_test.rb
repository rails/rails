require 'abstract_unit'
require 'rails/test_unit/reporter'

class TestUnitReporterTest < ActiveSupport::TestCase
  class ExampleTest < Minitest::Test
    def woot; end
  end

  setup do
    @output = StringIO.new
    @reporter = Rails::TestUnitReporter.new @output
  end

  test "prints rerun snippet to run a single failed test" do
    @reporter.results << failed_test
    @reporter.report

    assert_match %r{^bin/rails test .*test/test_unit/reporter_test.rb:6$}, @output.string
    assert_rerun_snippet_count 1
  end

  test "prints rerun snippet for every failed test" do
    @reporter.results << failed_test
    @reporter.results << failed_test
    @reporter.results << failed_test
    @reporter.report

    assert_rerun_snippet_count 3
  end

  test "does not print snippet for successful and skipped tests" do
    skip "confirm the expected behavior with Arthur"
    @reporter.results << passing_test
    @reporter.results << skipped_test
    @reporter.report
    assert_rerun_snippet_count 0
  end

  test "prints rerun snippet for skipped tests if run in verbose mode" do
    skip "confirm the expected behavior with Arthur"
    verbose = Rails::TestUnitReporter.new @output, verbose: true
    verbose.results << skipped_test
    verbose.report

    assert_rerun_snippet_count 1
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

  def passing_test
    ExampleTest.new(:woot)
  end

  def skipped_test
    st = ExampleTest.new(:woot)
    st.failures << begin
                     raise Minitest::Skip
                   rescue Minitest::Assertion => e
                     e
                   end
    st
  end
end

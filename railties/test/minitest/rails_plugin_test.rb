# frozen_string_literal: true

require "abstract_unit"

class Minitest::RailsPluginTest < ActiveSupport::TestCase
  setup do
    @options = Minitest.process_args []
    @output = StringIO.new("".encode("UTF-8"))
  end

  test "default reporters are replaced" do
    with_reporter Minitest::CompositeReporter.new do |reporter|
      reporter << Minitest::SummaryReporter.new(@output, @options)
      reporter << Minitest::ProgressReporter.new(@output, @options)
      reporter << Minitest::Reporter.new(@output, @options)

      Minitest.plugin_rails_init({})

      assert_equal 3, reporter.reporters.count
      assert reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::SuppressedSummaryReporter) }
      assert reporter.reporters.any? { |candidate| candidate.kind_of?(::Rails::TestUnitReporter) }
      assert reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::Reporter) }
    end
  end

  test "no custom reporters are added if nothing to replace" do
    with_reporter Minitest::CompositeReporter.new do |reporter|
      Minitest.plugin_rails_init({})

      assert_empty reporter.reporters
    end
  end

  private
    def with_reporter(reporter)
      old_reporter, Minitest.reporter =  Minitest.reporter, reporter

      yield reporter
    ensure
      Minitest.reporter = old_reporter
    end
end

# frozen_string_literal: true

require "abstract_unit"

class Minitest::RailsPluginTest < ActiveSupport::TestCase
  setup do
    @options = Minitest.process_args []
    @output = StringIO.new("".encode("UTF-8"))
  end

  test "default reporters are replaced" do
    reporter = Minitest::CompositeReporter.new
    reporter << Minitest::SummaryReporter.new(@output, @options)
    reporter << Minitest::ProgressReporter.new(@output, @options)
    reporter << Minitest::Reporter.new(@output, @options)

    Minitest::plugin_rails_replace_reporters(reporter, {})

    assert_equal 3, reporter.reporters.count
    assert reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::SuppressedSummaryReporter) }
    assert reporter.reporters.any? { |candidate| candidate.kind_of?(::Rails::TestUnitReporter) }
    assert reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::Reporter) }
  end

  test "no custom reporters are added if nothing to replace" do
    reporter = Minitest::CompositeReporter.new

    Minitest::plugin_rails_replace_reporters(reporter, {})

    assert_equal 0, reporter.reporters.count
  end

  test "handle the case when reporter is not CompositeReporter" do
    reporter = Minitest::Reporter.new

    Minitest::plugin_rails_replace_reporters(reporter, {})
  end
end

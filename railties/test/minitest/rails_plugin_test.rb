# frozen_string_literal: true

require "abstract_unit"
require "env_helpers"

class Minitest::RailsPluginTest < ActiveSupport::TestCase
  include EnvHelpers

  setup do
    @output = StringIO.new("".encode("UTF-8"))
  end

  test "replaces backtrace filter with one that silences gem lines" do
    backtrace = ["lib/my_code.rb", backtrace_gem_line("rails")]

    with_plugin do
      assert_equal backtrace.take(1), Minitest.backtrace_filter.filter(backtrace)
    end
  end

  test "replacement backtrace filter never returns an empty backtrace" do
    backtrace = [backtrace_gem_line("rails")]

    with_plugin do
      assert_equal backtrace, Minitest.backtrace_filter.filter(backtrace)
    end
  end

  test "replacement backtrace filter silences Minitest lines when all lines are gem lines" do
    backtrace = [backtrace_gem_line("rails"), backtrace_gem_line("minitest")]

    with_plugin do
      assert_equal backtrace.take(1), Minitest.backtrace_filter.filter(backtrace)
    end
  end

  test "does not replace backtrace filter when using --backtrace option" do
    backtrace_filter = baseline_backtrace_filter

    with_plugin("--backtrace", initial_backtrace_filter: backtrace_filter) do
      assert_same backtrace_filter, Minitest.backtrace_filter
    end

    with_plugin("-b", initial_backtrace_filter: backtrace_filter) do
      assert_same backtrace_filter, Minitest.backtrace_filter
    end
  end

  test "does not replace backtrace filter when BACKTRACE environment variable is set" do
    backtrace_filter = baseline_backtrace_filter

    switch_env "BACKTRACE", "true" do
      with_plugin(initial_backtrace_filter: backtrace_filter) do
        assert_same backtrace_filter, Minitest.backtrace_filter
      end
    end
  end

  test "replaces Minitest::SummaryReporter reporter" do
    with_plugin do
      assert_empty Minitest.reporter.reporters.select { |reporter| reporter.instance_of? Minitest::SummaryReporter }
      assert_not_empty Minitest.reporter.reporters.grep(Minitest::SuppressedSummaryReporter)
    end
  end

  test "replaces Minitest::ProgressReporter reporter" do
    with_plugin do
      assert_empty Minitest.reporter.reporters.grep(Minitest::ProgressReporter)
      assert_not_empty Minitest.reporter.reporters.grep(::Rails::TestUnitReporter)
    end
  end

  test "keeps non-default reporters" do
    custom_reporter = Minitest::Reporter.new(@output)

    with_plugin(initial_reporters: [custom_reporter]) do
      assert_includes Minitest.reporter.reporters, custom_reporter
    end
  end

  test "does not add reporters when not replacing reporters" do
    with_plugin(initial_reporters: []) do
      assert_empty Minitest.reporter.reporters
    end
  end

  private
    def baseline_backtrace_filter
      Minitest::BacktraceFilter.new
    end

    def baseline_reporters
      [Minitest::SummaryReporter.new(@output), Minitest::ProgressReporter.new(@output)]
    end

    def with_plugin(*args, initial_backtrace_filter: baseline_backtrace_filter, initial_reporters: baseline_reporters)
      original_backtrace_filter, Minitest.backtrace_filter = Minitest.backtrace_filter, initial_backtrace_filter
      original_reporter, Minitest.reporter = Minitest.reporter, Minitest::CompositeReporter.new(*initial_reporters)

      options = Minitest.process_args(args)
      Minitest.plugin_rails_init(options)

      yield
    ensure
      Minitest.backtrace_filter = original_backtrace_filter
      Minitest.reporter = original_reporter
    end

    def backtrace_gem_line(gem_name)
      caller.grep(%r"/lib/minitest\.rb:").first.gsub("minitest", gem_name)
    end
end

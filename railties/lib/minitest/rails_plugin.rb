# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "rails/test_unit/reporter"
require "rails/test_unit/runner"

module Minitest
  class BacktraceFilterWithFallback
    def initialize(preferred, fallback)
      @preferred = preferred
      @fallback = fallback
    end

    def filter(backtrace)
      filtered = @preferred.filter(backtrace)
      filtered = @fallback.filter(backtrace) if filtered.empty?
      filtered
    end
  end

  class SuppressedSummaryReporter < SummaryReporter
    # Disable extra failure output after a run if output is inline.
    def aggregated_results(*)
      super unless options[:output_inline]
    end
  end

  class ProfileReporter < Reporter
    def initialize(io = $stdout, options = {})
      super
      @results = []
      @count = options[:profile]
    end

    def record(result)
      @results << result
    end

    def report
      total_time = @results.sum(&:time)

      @results.sort! { |a, b| b.time <=> a.time }
      slow_results = @results.take(@count)
      slow_tests_total_time = slow_results.sum(&:time)

      ratio = (total_time == 0) ? 0.0 : (slow_tests_total_time / total_time) * 100

      io.puts("\nTop %d slowest tests (%.2f seconds, %.1f%% of total time):\n" % [slow_results.size, slow_tests_total_time, ratio])
      slow_results.each do |result|
        io.puts("  %s\n    %.4f seconds %s\n" % [result.location, result.time, source_location(result)])
      end
      io.puts("\n")
    end

    private
      def source_location(result)
        filename, line = result.source_location
        return "" unless filename

        pwd = Dir.pwd
        if filename.start_with?(pwd)
          filename = Pathname.new(filename).relative_path_from(pwd)
        end
        "#{filename}:#{line}"
      end
  end

  def self.plugin_rails_options(opts, options)
    ::Rails::TestUnit::Runner.attach_before_load_options(opts)

    opts.on("-b", "--backtrace", "Show the complete backtrace") do
      options[:full_backtrace] = true
    end

    opts.on("-d", "--defer-output", "Output test failures and errors after the test run") do
      options[:output_inline] = false
    end

    opts.on("-f", "--fail-fast", "Abort test run on first failure or error") do
      options[:fail_fast] = true
    end

    opts.on("-c", "--[no-]color", "Enable color in the output") do |value|
      options[:color] = value
    end

    opts.on("--profile [COUNT]", "Enable profiling of tests and list the slowest test cases (default: 10)") do |value|
      default_count = 10

      if value.nil?
        count = default_count
      else
        count = Integer(value, exception: false)
        if count.nil?
          warn("Non integer specified as profile count, separate " \
               "your path from options with -- e.g. " \
               "`#{::Rails::TestUnitReporter.executable} --profile -- #{value}`")
          count = default_count
        end
      end

      options[:profile] = count
    end

    options[:color] = true
    options[:output_inline] = true
  end

  # Owes great inspiration to test runner trailblazers like RSpec,
  # minitest-reporters, maxitest, and others.
  def self.plugin_rails_init(options)
    # Don't mess with Minitest unless RAILS_ENV is set
    return unless ENV["RAILS_ENV"] || ENV["RAILS_MINITEST_PLUGIN"]

    unless options[:full_backtrace]
      # Plugin can run without Rails loaded, check before filtering.
      if ::Rails.respond_to?(:backtrace_cleaner)
        Minitest.backtrace_filter = BacktraceFilterWithFallback.new(::Rails.backtrace_cleaner, Minitest.backtrace_filter)
      end
    end

    # Suppress summary reports when outputting inline rerun snippets.
    if reporter.reporters.reject! { |reporter| reporter.kind_of?(SummaryReporter) }
      reporter << SuppressedSummaryReporter.new(options[:io], options)
    end

    # Replace progress reporter for colors.
    if reporter.reporters.reject! { |reporter| reporter.kind_of?(ProgressReporter) }
      reporter << ::Rails::TestUnitReporter.new(options[:io], options)
    end

    # Add slowest tests reporter at the end.
    if options[:profile]
      reporter << ProfileReporter.new(options[:io], options)
    end
  end

  # Backwards compatibility with Rails 5.0 generated plugin test scripts
  mattr_reader :run_via, default: {}
end

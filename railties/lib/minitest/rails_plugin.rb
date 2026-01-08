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
    attr_accessor :results

    def initialize(io = $stdout, options = {})
      super
      @results = []
      @count = options[:profile]
    end

    def record(result)
      if output_file = ENV["RAILTIES_OUTPUT_FILE"]
        File.open(output_file, "a") do |f|
          # Round-trip for re-serialization
          data = JSON.parse(result.to_json)
          data[:location] = result.location
          f.puts(data.to_json)
        end
      else
        @results << result
      end
    end

    def passed?
      true
    end

    def report
      # Skip if we're outputting to a file
      return if ENV["RAILTIES_OUTPUT_FILE"]
      print_summary
    end

    def summary
      print_summary
    end

    private
      def print_summary
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

    if Minitest::VERSION > "6" then
      opts.on "-n", "--name PATTERN", "Include /regexp/ or string for run." do |a|
        warn "Please switch from -n/--name to -i/--include"
        options[:include] = a
      end
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

    opts.on(/^[^-]/) do |test_file|
      options[:test_files] ||= []
      options[:test_files] << test_file
    end

    options[:color] = true
    options[:output_inline] = true

    opts.on do
      if ::Rails::TestUnit::Runner.load_test_files
        ::Rails::TestUnit::Runner.load_tests(options.fetch(:test_files, []))
      end
    end
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

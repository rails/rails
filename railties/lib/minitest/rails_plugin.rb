# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "rails/test_unit/reporter"
require "rails/test_unit/runner"

module Minitest
  class SuppressedSummaryReporter < SummaryReporter
    # Disable extra failure output after a run if output is inline.
    def aggregated_results(*)
      super unless options[:output_inline]
    end
  end

  def self.plugin_rails_options(opts, options)
    Rails::TestUnit::Runner.attach_before_load_options(opts)

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

    options[:color] = true
    options[:output_inline] = true
  end

  # Owes great inspiration to test runner trailblazers like RSpec,
  # minitest-reporters, maxitest and others.
  def self.plugin_rails_init(options)
    unless options[:full_backtrace] || ENV["BACKTRACE"]
      # Plugin can run without Rails loaded, check before filtering.
      Minitest.backtrace_filter = ::Rails.backtrace_cleaner if ::Rails.respond_to?(:backtrace_cleaner)
    end

    # Suppress summary reports when outputting inline rerun snippets.
    if reporter.reporters.reject! { |reporter| reporter.kind_of?(SummaryReporter) }
      reporter << SuppressedSummaryReporter.new(options[:io], options)
    end

    # Replace progress reporter for colors.
    if reporter.reporters.reject! { |reporter| reporter.kind_of?(ProgressReporter) }
      reporter << ::Rails::TestUnitReporter.new(options[:io], options)
    end
  end

  # Backwardscompatibility with Rails 5.0 generated plugin test scripts
  mattr_reader :run_via, default: {}
end

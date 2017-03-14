require "active_support/core_ext/module/attribute_accessors"
require "rails/test_unit/reporter"
require "rails/test_unit/test_requirer"
require "shellwords"

module Minitest
  class SuppressedSummaryReporter < SummaryReporter
    # Disable extra failure output after a run if output is inline.
    def aggregated_results
      super unless options[:output_inline]
    end
  end

  def self.plugin_rails_options(opts, options)
    executable = ::Rails::TestUnitReporter.executable
    opts.separator ""
    opts.separator "Usage: #{executable} [options] [files or directories]"
    opts.separator "You can run a single test by appending a line number to a filename:"
    opts.separator ""
    opts.separator "    #{executable} test/models/user_test.rb:27"
    opts.separator ""
    opts.separator "You can run multiple files and directories at the same time:"
    opts.separator ""
    opts.separator "    #{executable} test/controllers test/integration/login_test.rb"
    opts.separator ""
    opts.separator "By default test failures and errors are reported inline during a run."
    opts.separator ""

    opts.separator "Rails options:"
    opts.on("-e", "--environment ENV",
            "Run tests in the ENV environment") do |env|
      options[:environment] = env.strip
    end

    opts.on("-b", "--backtrace",
            "Show the complete backtrace") do
      options[:full_backtrace] = true
    end

    opts.on("-d", "--defer-output",
            "Output test failures and errors after the test run") do
      options[:output_inline] = false
    end

    opts.on("-f", "--fail-fast",
            "Abort test run on first failure or error") do
      options[:fail_fast] = true
    end

    opts.on("-c", "--[no-]color",
            "Enable color in the output") do |value|
      options[:color] = value
    end

    opts.on("-w", "--warnings",
            "Enable ruby warnings") do
      $VERBOSE = true
    end

    options[:color] = true
    options[:output_inline] = true
    options[:patterns] = opts.order! unless run_via.rake?
  end

  def self.rake_run(patterns, exclude_patterns = []) # :nodoc:
    self.run_via = :rake unless run_via.set?
    ::Rails::TestRequirer.require_files(patterns, exclude_patterns)
    autorun
  end

  module RunRespectingRakeTestopts
    def run(args = [])
      if run_via.rake?
        args = Shellwords.split(ENV["TESTOPTS"] || "")
      end

      super
    end
  end

  singleton_class.prepend RunRespectingRakeTestopts

  # Owes great inspiration to test runner trailblazers like RSpec,
  # minitest-reporters, maxitest and others.
  def self.plugin_rails_init(options)
    ENV["RAILS_ENV"] = options[:environment] || "test"

    # If run via `ruby` we've been passed the files to run directly, or if run
    # via `rake` then they have already been eagerly required.
    unless run_via.ruby? || run_via.rake?
      # If there are no given patterns, we can assume that the user
      # simply runs the `bin/rails test` command without extra arguments.
      if options[:patterns].empty?
        ::Rails::TestRequirer.require_files(options[:patterns], ["test/system/**/*"])
      else
        ::Rails::TestRequirer.require_files(options[:patterns])
      end
    end

    unless options[:full_backtrace] || ENV["BACKTRACE"]
      # Plugin can run without Rails loaded, check before filtering.
      Minitest.backtrace_filter = ::Rails.backtrace_cleaner if ::Rails.respond_to?(:backtrace_cleaner)
    end

    # Replace progress reporter for colors.
    reporter.reporters.delete_if { |reporter| reporter.kind_of?(SummaryReporter) || reporter.kind_of?(ProgressReporter) }
    reporter << SuppressedSummaryReporter.new(options[:io], options)
    reporter << ::Rails::TestUnitReporter.new(options[:io], options)
  end

  def self.run_via=(runner)
    if run_via.set?
      raise ArgumentError, "run_via already assigned"
    else
      run_via.runner = runner
    end
  end

  class RunVia
    attr_accessor :runner
    alias set? runner

    # Backwardscompatibility with Rails 5.0 generated plugin test scripts.
    def []=(runner, *)
      @runner = runner
    end

    def ruby?
      runner == :ruby
    end

    def rake?
      runner == :rake
    end
  end

  mattr_reader(:run_via) { RunVia.new }
end

# Put Rails as the first plugin minitest initializes so other plugins
# can override or replace our default reporter setup.
# Since minitest only loads plugins if its extensions are empty we have
# to call `load_plugins` first.
Minitest.load_plugins
Minitest.extensions.unshift "rails"

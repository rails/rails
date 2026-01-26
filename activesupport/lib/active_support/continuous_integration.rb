# frozen_string_literal: true

require "optparse"
require "active_support/core_ext/object/with"

module ActiveSupport
  # Provides a DSL for declaring a continuous integration workflow that can be run either locally or in the cloud.
  # Each step is timed, reports success/error, and is aggregated into a collective report that reports total runtime,
  # as well as whether the entire run was successful or not.
  #
  # Example:
  #
  #   ActiveSupport::ContinuousIntegration.run do
  #     step "Setup", "bin/setup --skip-server"
  #     step "Style: Ruby", "bin/rubocop"
  #     step "Security: Gem audit", "bin/bundler-audit"
  #     step "Tests: Rails", "bin/rails test test:system"
  #
  #     if success?
  #       step "Signoff: Ready for merge and deploy", "gh signoff"
  #     else
  #       failure "Skipping signoff; CI failed.", "Fix the issues and try again."
  #     end
  #   end
  #
  # Starting with Rails 8.1, a default `bin/ci` and `config/ci.rb` file are created to provide out-of-the-box CI.
  class ContinuousIntegration
    COLORS = {
      banner: "\033[1;32m",   # Green
      title: "\033[1;35m",    # Purple
      subtitle: "\033[1;90m", # Medium Gray
      error: "\033[1;31m",    # Red
      success: "\033[1;32m"   # Green
    }

    attr_reader :results
    attr_accessor :current_groups # :nodoc:

    # Perform a CI run. Execute each step, show their results and runtime, and exit with a non-zero status if there are any failures.
    #
    # Pass an optional title, subtitle, and a block that declares the steps to be executed.
    #
    # Sets the CI environment variable to "true" to allow for conditional behavior in the app, like enabling eager loading and disabling logging.
    #
    # A 'fail fast' option can be passed as a CLI argument (-f or --fail-fast). This exits with a non-zero status directly after a step fails.
    #
    # Example:
    #
    #   ActiveSupport::ContinuousIntegration.run do
    #     step "Setup", "bin/setup --skip-server"
    #     step "Style: Ruby", "bin/rubocop"
    #     step "Security: Gem audit", "bin/bundler-audit"
    #     step "Tests: Rails", "bin/rails test test:system"
    #
    #     if success?
    #       step "Signoff: Ready for merge and deploy", "gh signoff"
    #     else
    #       failure "Skipping signoff; CI failed.", "Fix the issues and try again."
    #     end
    #   end
    def self.run(title = "Continuous Integration", subtitle = "Running tests, style checks, and security audits", &block)
      new.tap do |ci|
        ENV["CI"] = "true"
        ci.heading title, subtitle, padding: false
        ci.report(title, &block)
        abort unless ci.success?
      end
    end

    def initialize
      @results = []
      @current_groups = []
      @included_groups = []
      @fail_fast = false
      parse_flags
    end

    # Declare a step with a title and a command. The command can either be given as a single string or as multiple
    # strings that will be passed to `system` as individual arguments (and therefore correctly escaped for paths etc).
    #
    # Steps inside groups will only run when:
    # - No group filter is specified (runs everything), OR
    # - The step is inside a group that matches the filter
    #
    # Steps outside of any group will only run when no group filter is specified.
    #
    # Examples:
    #
    #   step "Setup", "bin/setup"
    #   step "Single test", "bin/rails", "test", "--name", "test_that_is_one"
    def step(title, *command)
      return unless should_run?

      heading title, command.join(" "), type: :title
      report(title) { results << [ system(*command), title ] }
    end

    # Declare a group of related steps. Groups can be filtered using the -g/--group flag.
    # Groups can be nested to create hierarchical organization.
    #
    # When filtering by group name, specifying a parent group will run all nested groups within it.
    # Steps outside of any group will only run when no group filter is specified.
    #
    # Examples:
    #
    #   step "Single test", "bin/rails", "test", "--name", "test_that_is_one" # Will run when no group is specified
    #
    #   group "lint" do
    #     step "RuboCop", "bin/rubocop"
    #     step "ESLint", "yarn", "lint"
    #   end
    #
    #   # Nested groups
    #   group "backend" do
    #     group "unit" do
    #       step "Models", "bin/rails test test/models"
    #     end
    #
    #     group "integration" do
    #       step "API", "bin/rails test test/integration"
    #     end
    #   end
    #
    # Usage:
    #   $ bin/ci -g backend # Runs all backend tests (unit and integration)
    #   $ bin/ci --group unit # Runs only the unit group
    #   $ bin/ci -g lint,backend # Runs only the lint and backend groups
    #   $ bin/ci # Runs everything when no group is specified
    def group(name, subtitle = nil, &block)
      with(current_groups: current_groups + [name]) do
        heading "Group: #{name}", subtitle, type: :banner, padding: true if should_run?
        instance_eval(&block)
      end
    end

    # Returns true if all steps were successful.
    def success?
      results.map(&:first).all?
    end

    # Display an error heading with the title and optional subtitle to reflect that the run failed.
    def failure(title, subtitle = nil)
      heading title, subtitle, type: :error
    end

    # Display a colorized heading followed by an optional subtitle.
    #
    # Examples:
    #
    #   heading "Smoke Testing", "End-to-end tests verifying key functionality", padding: false
    #   heading "Skipping video encoding tests", "Install FFmpeg to run these tests", type: :error
    #
    # See ActiveSupport::ContinuousIntegration::COLORS for a complete list of options.
    def heading(heading, subtitle = nil, type: :banner, padding: true)
      echo "#{padding ? "\n\n" : ""}#{heading}", type: type
      echo "#{subtitle}#{padding ? "\n" : ""}", type: :subtitle if subtitle
    end

    # Echo text to the terminal in the color corresponding to the type of the text.
    #
    # Examples:
    #
    #   echo "This is going to be green!", type: :success
    #   echo "This is going to be red!", type: :error
    #
    # See ActiveSupport::ContinuousIntegration::COLORS for a complete list of options.
    def echo(text, type:)
      puts colorize(text, type)
    end

    # :nodoc:
    def report(title, &block)
      Signal.trap("INT") { abort colorize("\n❌ #{title} interrupted", :error) }

      ci = self.class.new
      elapsed = timing { ci.instance_eval(&block) }

      if ci.success?
        echo "\n✅ #{title} passed in #{elapsed}", type: :success
      else
        echo "\n❌ #{title} failed in #{elapsed}", type: :error

        abort if ci.fail_fast?

        if ci.multiple_results?
          ci.failures.each do |success, title|
            unless success
              echo "   ↳ #{title} failed", type: :error
            end
          end
        end
      end

      results.concat ci.results
    ensure
      Signal.trap("INT", "-")
    end

    # :nodoc:
    def failures
      results.reject(&:first)
    end

    # :nodoc:
    def multiple_results?
      results.size > 1
    end

    # :nodoc:
    def fail_fast?
      @fail_fast
    end

    private
      attr_reader :included_groups

      def timing
        started_at = Time.now.to_f
        yield
        min, sec = (Time.now.to_f - started_at).divmod(60)
        "#{"#{min}m" if min > 0}%.2fs" % sec
      end

      def colorize(text, type)
        "#{COLORS.fetch(type)}#{text}\033[0m"
      end

      def parse_flags
        OptionParser.new do |opts|
          opts.on("-g GROUPS", "--group GROUPS", Array, "Run only steps in these groups (comma-separated)") do |groups|
            @included_groups.concat(groups)
          end
          opts.on("-f", "--fail-fast", "Exit on first failure") do
            @fail_fast = true
          end
        end.parse!(ARGV.dup)
      rescue OptionParser::InvalidOption
        # Ignore unknown options
      end

      def should_run?
        return true if included_groups.empty?
        return false if current_groups.empty?

        current_groups.any? { |g| included_groups.include?(g) }
      end
  end
end

# frozen_string_literal: true

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
      success: "\033[1;32m",  # Green
      progress: "\033[1;36m"  # Cyan
    }

    attr_reader :results

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
      ENV["CI"] = "true"
      new.tap { |ci| ci.run(title, subtitle, &block) }
    end

    def run(title, subtitle, &block)
      heading title, subtitle, padding: false
      success, seconds = execute(title, &block)
      result_line(title, success, seconds)
      abort unless success?
    end

    def initialize
      @results = []
    end

    # Declare a step with a title and a command. The command can either be given as a single string or as multiple
    # strings that will be passed to `system` as individual arguments (and therefore correctly escaped for paths etc).
    #
    # Examples:
    #
    #   step "Setup", "bin/setup"
    #   step "Single test", "bin/rails", "test", "--name", "test_that_is_one"
    def step(title, *command)
      previous_trap = Signal.trap("INT") { abort colorize("\n❌ #{title} interrupted", :error) }
      report_step(title, command) do
        started = Time.now.to_f
        [system(*command), Time.now.to_f - started]
      end
      abort if failing_fast?
    ensure
      Signal.trap("INT", previous_trap || "-")
    end

    # Declare a group of steps that can be run in parallel. Steps within the group are collected first,
    # then executed either concurrently (when +parallel+ > 1) or sequentially (when +parallel+ is 1).
    #
    # When running in parallel, each step's output is captured to avoid interleaving, and a progress
    # display shows which steps are currently running.
    #
    # Sub-groups within a parallel group occupy a single parallel slot and run their steps sequentially.
    #
    # Examples:
    #
    #   group "Checks", parallel: 3 do
    #     step "Style: Ruby", "bin/rubocop"
    #     step "Security: Brakeman", "bin/brakeman --quiet"
    #     step "Security: Gem audit", "bin/bundler-audit"
    #   end
    #
    #   group "Tests" do
    #     step "Unit tests", "bin/rails test"
    #     step "System tests", "bin/rails test:system"
    #   end
    def group(name, parallel: 1, &block)
      if parallel <= 1
        instance_eval(&block)
      else
        Group.new(self, name, parallel: parallel, &block).run
      end
      abort if failing_fast?
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
    def report_step(title, command)
      heading title, command.join(" "), type: :title
      success, seconds = yield
      result_line(title, success, seconds)
      results << [success, title]
      success
    end

    # :nodoc:
    def colorize(text, type)
      "#{COLORS.fetch(type)}#{text}\033[0m"
    end

    # :nodoc:
    def fail_fast?
      ARGV.include?("-f") || ARGV.include?("--fail-fast")
    end

    # :nodoc:
    def failing_fast?
      fail_fast? && failures.any?
    end

    private
      def failures
        results.reject(&:first)
      end

      def multiple_results?
        results.size > 1
      end

      def execute(title, &block)
        previous_trap = Signal.trap("INT") { abort colorize("\n❌ #{title} interrupted", :error) }

        seconds = timing { instance_eval(&block) }

        unless success?
          if multiple_results?
            failures.each do |success, title|
              unless success
                echo "   ↳ #{title} failed", type: :error
              end
            end
          end
        end

        [success?, seconds]
      ensure
        Signal.trap("INT", previous_trap || "-")
      end

      def result_line(title, success, seconds)
        elapsed = format_elapsed(seconds)
        if success
          echo "\n✅ #{title} passed in #{elapsed}", type: :success
        else
          echo "\n❌ #{title} failed in #{elapsed}", type: :error
        end
      end

      def format_elapsed(seconds)
        min, sec = seconds.divmod(60)
        "#{"#{min.to_i}m" if min > 0}%.2fs" % sec
      end

      def timing
        started_at = Time.now.to_f
        yield
        Time.now.to_f - started_at
      end
  end
end

require_relative "continuous_integration/group"

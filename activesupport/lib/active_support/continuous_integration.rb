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
      success: "\033[1;32m"   # Green
    }

    attr_reader :results

    # Perform a CI run. Execute each step, show their results and runtime, and exit with a non-zero status if there are any failures.
    #
    # Pass an optional title, subtitle, and a block that declares the steps to be executed.
    #
    # Sets the CI environment variable to "true" to allow for conditional behavior in the app, like enabling eager loading and disabling logging.
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
    end

    # Declare a step with a title and a command. The command can either be given as a single string or as multiple
    # strings that will be passed to `system` as individual arguments (and therefore correctly escaped for paths etc).
    #
    # Examples:
    #
    #   step "Setup", "bin/setup"
    #   step "Single test", "bin/rails", "test", "--name", "test_that_is_one"
    def step(title, *command)
      heading title, command.join(" "), type: :title
      report(title) { results << system(*command) }
    end

    # Returns true if all steps were successful.
    def success?
      results.all?
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
      Signal.trap("INT") { abort colorize(:error, "\n❌ #{title} interrupted") }

      ci = self.class.new
      elapsed = timing { ci.instance_eval(&block) }

      if ci.success?
        echo "\n✅ #{title} passed in #{elapsed}", type: :success
      else
        echo "\n❌ #{title} failed in #{elapsed}", type: :error
      end

      results.concat ci.results
    ensure
      Signal.trap("INT", "-")
    end

    private
      def timing
        started_at = Time.now.to_f
        yield
        min, sec = (Time.now.to_f - started_at).divmod(60)
        "#{"#{min}m" if min > 0}%.2fs" % sec
      end

      def colorize(text, type)
        "#{COLORS.fetch(type)}#{text}\033[0m"
      end
  end
end

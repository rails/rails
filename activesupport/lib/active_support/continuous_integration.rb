# frozen_string_literal: true

module ActiveSupport
  # Provides a DSL for declaring a continuous integration workflow that can be run either locally or in the cloud.
  # Each step is timed, reports success/error, and is aggregated into a collective report that reports total runtime,
  # as well as whether the run was successful or not.
  #
  # Example:
  #
  #   ActiveSupport::ContinuousIntegration.new do
  #     echo :banner, "🚀 Local CI"
  #     echo :subtitle, "Running tests, style checks, and security audits"
  #
  #     report "Local CI" do
  #       step "Setup", "bin/setup --skip-server"
  #       step "Style: Ruby", "bin/rubocop"
  #       step "Security: Gem audit", "bin/bundler-audit"
  #       step "Tests: Rails", "bin/rails test test:system"
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

    def initialize(&block)
      @results = []
      instance_eval(&block) if block_given?
    end

    # Declare a step with a title and a command. The command can either be given as a single string or as multiple
    # strings that will be passed to `system` as individual arguments (and therefore correctly escaped for paths etc).
    #
    # Examples:
    #
    #   step "Setup", "bin/setup"
    #   step "Single test", "bin/rails", "test", "--name", "test_that_is_one"
    def step(title, *command)
      echo :title, "\n\n#{title}"
      echo :subtitle, "#{command.join(" ")}\n"

      report(title) { results << system(*command) }
    end

    # Aggregate a number of steps under a single heading, with a combined runtime, and an aggregate success/failure state.
    #
    # Example:
    #
    #   report "Local CI" do
    #     step "Setup", "bin/setup --skip-server"
    #     step "Style: Ruby", "bin/rubocop"
    #   end
    def report(title, &block)
      Signal.trap("INT") { abort colorize(:error, "\n❌ #{title} interrupted") }

      ci = self.class.new
      elapsed = timing { ci.instance_eval(&block) }

      if ci.results.all?(&:itself)
        echo :success, "\n✅ #{title} passed in #{elapsed}"
      else
        echo :error, "\n❌ #{title} failed in #{elapsed}"
      end

      results.concat ci.results
    ensure
      Signal.trap("INT", "-")
    end

    # Echo text to the terminal in the color corresponding to the type of the text.
    #
    # Examples:
    #
    #   echo :success, "This is going to be green!"
    #   echo :error, "This is going to be red!"
    #
    # See ActiveSupport::ContinuousIntegration::COLORS for a complete list of options.
    def echo(type, text)
      puts colorize(type, text)
    end

    private
      def timing
        started_at = Time.now.to_f
        yield
        min, sec = (Time.now.to_f - started_at).divmod(60)
        "#{"#{min}m" if min > 0}%.2fs" % sec
      end

      def colorize(type, text)
        "#{COLORS[type]}#{text}\033[0m"
      end
  end
end

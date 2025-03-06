# frozen_string_literal: true

module ActiveSupport
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

    def step(title, *command)
      echo :title, "\n\n#{title}"
      echo :subtitle, "#{command.join(" ")}\n"

      report(title) { results << system(*command) }
    end

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

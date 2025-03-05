module ActiveSupport
  class ContinuousIntegration
    COLORS = {
      banner: "\033[1;32m",   # Green
      title: "\033[1;35m",    # Purple
      subtitle: "\033[1;90m", # Medium Gray
      error: "\033[1;31m",    # Red
      success: "\033[1;32m"   # Green
    }

    def self.run(ci_declaration_path)
      new.instance_eval(ci_declaration_path.read)
    end

    def initialize
    end

    def step(title, command)
      echo :title, "\n\n#{title}"
      echo :subtitle, "#{command}\n"

      report(title) { system command }
    end

    def report(title)
      Signal.trap("INT") { abort message(:error, "\n\n❌ #{title} interrupted") }

      result = nil
      elapsed = timing { result = yield }

      if result
        echo :success, "\n\n✅ #{title} passed in #{elapsed}"
        true
      else
        echo :error, "\n\n❌ #{title} failed in #{elapsed}"
        false
      end
    ensure
      Signal.trap("INT", "-")
    end

    def echo(type, text)
      puts message(type, text)
    end

    private
      def timing
        started_at = Time.now.to_f
        yield
        min, sec = (Time.now.to_f - started_at).divmod(60)
        "#{"#{min}m" if min > 0}%.2fs" % sec
      end

      def message(type, text)
        "#{COLORS[type]}#{text}\033[0m"
      end
  end
end

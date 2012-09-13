require "active_support/notifications"

module ActiveSupport
  class Deprecation
    # Default warning behaviors per Rails.env.
    DEFAULT_BEHAVIORS = {
      :stderr => Proc.new { |message, callstack|
        $stderr.puts(message)
        $stderr.puts callstack.join("\n  ") if debug
      },
      :log => Proc.new { |message, callstack|
        logger =
            if defined?(Rails) && Rails.logger
              Rails.logger
            else
              require 'active_support/logger'
              ActiveSupport::Logger.new($stderr)
            end
        logger.warn message
        logger.debug callstack.join("\n  ") if debug
      },
      :notify => Proc.new { |message, callstack|
        ActiveSupport::Notifications.instrument("deprecation.rails",
                                                :message => message, :callstack => callstack)
      },
      :silence => Proc.new { |message, callstack| }
    }

    module Behavior
      # Whether to print a backtrace along with the warning.
      attr_accessor :debug

      # Returns the current behavior or if one isn't set, defaults to +:stderr+
      def behavior
        @behavior ||= [DEFAULT_BEHAVIORS[:stderr]]
      end

      # Sets the behavior to the specified value. Can be a single value, array, or
      # an object that responds to +call+.
      #
      # Available behaviors:
      #
      # [+stderr+]  Log all deprecation warnings to +$stderr+.
      # [+log+]     Log all deprecation warnings to +Rails.logger+.
      # [+notify+]  Use +ActiveSupport::Notifications+ to notify +deprecation.rails+.
      # [+silence+] Do nothing.
      #
      # Setting behaviors only affects deprecations that happen after boot time.
      # Deprecation warnings raised by gems are not affected by this setting because
      # they happen before Rails boots up.
      #
      #   ActiveSupport::Deprecation.behavior = :stderr
      #   ActiveSupport::Deprecation.behavior = [:stderr, :log]
      #   ActiveSupport::Deprecation.behavior = MyCustomHandler
      #   ActiveSupport::Deprecation.behavior = proc { |message, callstack|
      #     # custom stuff
      #   }
      def behavior=(behavior)
        @behavior = Array(behavior).map { |b| DEFAULT_BEHAVIORS[b] || b }
      end
    end
  end
end

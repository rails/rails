# frozen_string_literal: true

require "active_support/notifications"

module ActiveSupport
  # Raised when ActiveSupport::Deprecation::Behavior#behavior is set with <tt>:raise</tt>.
  # You would set <tt>:raise</tt>, as a behavior to raise errors and proactively report exceptions from deprecations.
  class DeprecationException < StandardError
  end

  class Deprecation
    # Default warning behaviors per Rails.env.
    DEFAULT_BEHAVIORS = {
      raise: ->(message, callstack, deprecator) do
        e = DeprecationException.new(message)
        e.set_backtrace(callstack.map(&:to_s))
        raise e
      end,

      stderr: ->(message, callstack, deprecator) do
        $stderr.puts(message)
        $stderr.puts callstack.join("\n  ") if deprecator.debug
      end,

      log: ->(message, callstack, deprecator) do
        logger =
            if defined?(Rails.logger) && Rails.logger
              Rails.logger
            else
              require "active_support/logger"
              ActiveSupport::Logger.new($stderr)
            end
        logger.warn message
        logger.debug callstack.join("\n  ") if deprecator.debug
      end,

      notify: ->(message, callstack, deprecator) do
        ActiveSupport::Notifications.instrument(
          "deprecation.#{deprecator.gem_name.underscore.tr("/", "_")}",
          message: message,
          callstack: callstack,
          gem_name: deprecator.gem_name,
          deprecation_horizon: deprecator.deprecation_horizon,
        )
      end,

      silence: ->(message, callstack, deprecator) { },

      report: ->(message, callstack, deprecator) do
        error = DeprecationException.new(message)
        error.set_backtrace(callstack.map(&:to_s))
        ActiveSupport.error_reporter.report(error)
      end
    }

    # Behavior module allows to determine how to display deprecation messages.
    # You can create a custom behavior or set any from the +DEFAULT_BEHAVIORS+
    # constant. Available behaviors are:
    #
    # [+:raise+]   Raise ActiveSupport::DeprecationException.
    # [+:stderr+]  Log all deprecation warnings to <tt>$stderr</tt>.
    # [+:log+]     Log all deprecation warnings to +Rails.logger+.
    # [+:notify+]  Use ActiveSupport::Notifications to notify +deprecation.rails+.
    # [+:report+]  Use ActiveSupport::ErrorReporter to report deprecations.
    # [+:silence+] Do nothing. On \Rails, set <tt>config.active_support.report_deprecations = false</tt> to disable all behaviors.
    #
    # Setting behaviors only affects deprecations that happen after boot time.
    # For more information you can read the documentation of the #behavior= method.
    module Behavior
      # Whether to print a backtrace along with the warning.
      attr_accessor :debug

      # Returns the current behavior or if one isn't set, defaults to +:stderr+.
      def behavior
        @behavior ||= [DEFAULT_BEHAVIORS[:stderr]]
      end

      # Returns the current behavior for disallowed deprecations or if one isn't set, defaults to +:raise+.
      def disallowed_behavior
        @disallowed_behavior ||= [DEFAULT_BEHAVIORS[:raise]]
      end

      # Sets the behavior to the specified value. Can be a single value, array,
      # or an object that responds to +call+.
      #
      # Available behaviors:
      #
      # [+:raise+]   Raise ActiveSupport::DeprecationException.
      # [+:stderr+]  Log all deprecation warnings to <tt>$stderr</tt>.
      # [+:log+]     Log all deprecation warnings to +Rails.logger+.
      # [+:notify+]  Use ActiveSupport::Notifications to notify +deprecation.rails+.
      # [+:report+]  Use ActiveSupport::ErrorReporter to report deprecations.
      # [+:silence+] Do nothing.
      #
      # Setting behaviors only affects deprecations that happen after boot time.
      # Deprecation warnings raised by gems are not affected by this setting
      # because they happen before \Rails boots up.
      #
      #   deprecator = ActiveSupport::Deprecation.new
      #   deprecator.behavior = :stderr
      #   deprecator.behavior = [:stderr, :log]
      #   deprecator.behavior = MyCustomHandler
      #   deprecator.behavior = ->(message, callstack, deprecation_horizon, gem_name) {
      #     # custom stuff
      #   }
      #
      # If you are using \Rails, you can set
      # <tt>config.active_support.report_deprecations = false</tt> to disable
      # all deprecation behaviors. This is similar to the +:silence+ option but
      # more performant.
      def behavior=(behavior)
        @behavior = Array(behavior).map { |b| DEFAULT_BEHAVIORS[b] || arity_coerce(b) }
      end

      # Sets the behavior for disallowed deprecations (those configured by
      # ActiveSupport::Deprecation#disallowed_warnings=) to the specified
      # value. As with #behavior=, this can be a single value, array, or an
      # object that responds to +call+.
      def disallowed_behavior=(behavior)
        @disallowed_behavior = Array(behavior).map { |b| DEFAULT_BEHAVIORS[b] || arity_coerce(b) }
      end

      private
        def arity_coerce(behavior)
          unless behavior.respond_to?(:call)
            raise ArgumentError, "#{behavior.inspect} is not a valid deprecation behavior."
          end

          case arity_of_callable(behavior)
          when 2
            ->(message, callstack, deprecator) do
              behavior.call(message, callstack)
            end
          when -2..3
            behavior
          else
            ->(message, callstack, deprecator) do
              behavior.call(message, callstack, deprecator.deprecation_horizon, deprecator.gem_name)
            end
          end
        end

        def arity_of_callable(callable)
          callable.respond_to?(:arity) ? callable.arity : callable.method(:call).arity
        end
    end
  end
end

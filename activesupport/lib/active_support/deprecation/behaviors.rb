module ActiveSupport
  module Deprecation
    class << self
      # Behavior is a block that takes a message argument.
      attr_writer :behavior

      # Whether to print a backtrace along with the warning.
      attr_accessor :debug

      def behavior
        @behavior ||= default_behavior
      end

      def default_behavior
        Deprecation::DEFAULT_BEHAVIORS[defined?(Rails) ? Rails.env.to_s : 'test']
      end
    end

    # Default warning behaviors per Rails.env. Ignored in production.
    DEFAULT_BEHAVIORS = {
      'test' => Proc.new { |message, callstack|
         $stderr.puts(message)
         $stderr.puts callstack.join("\n  ") if debug
       },
      'development' => Proc.new { |message, callstack|
         logger = defined?(Rails) ? Rails.logger : Logger.new($stderr)
         logger.warn message
         logger.debug callstack.join("\n  ") if debug
       }
    }
  end
end

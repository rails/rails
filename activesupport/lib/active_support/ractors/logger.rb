# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ActiveSupport
  module Ractors # :nodoc:
    # A Ractor-shareable +ActiveSupport::Logger+.
    #
    # +flush+ honors the Rails per-request contract: Rails::Rack::Logger calls ActiveSupport::LogSubscriber.flush_all!,
    # which calls +#flush+ on the logger to drain a request's logs before the next request is processed.
    class Logger < ActiveSupport::Logger # :nodoc:
      def initialize(*args, level: ::Logger::DEBUG, progname: nil, formatter: nil, datetime_format: nil, **logdev_options)
        super(nil, level: level, progname: progname, formatter: formatter, datetime_format: datetime_format)
        @logdev = DeviceProxy.new(*args, **logdev_options)
      end

      delegate :flush, to: :@logdev

      # ::Logger keeps per-Fiber level overrides in a hash keyed by ::Logger#level_key, which returns
      # +Fiber.current+. That key can't be computed from a non-main Ractor, and the hash is shared
      # mutable state. Active Support already provides Ractor-safe per-execution-context levels through
      # ActiveSupport::LoggerThreadSafeLevel, so bypass the ::Logger implementation entirely.
      def level
        local_level || @level
      end

      def with_level(severity, &block)
        log_at(coerce_level(severity), &block)
      end

      extend ActiveSupport::Autoload
      autoload :DeviceProxy
      autoload :Writer

      private
        def coerce_level(severity)
          return severity if severity.is_a?(Integer)

          case severity.to_s.downcase
          when "debug" then ::Logger::DEBUG
          when "info" then ::Logger::INFO
          when "warn" then ::Logger::WARN
          when "error" then ::Logger::ERROR
          when "fatal" then ::Logger::FATAL
          when "unknown" then ::Logger::UNKNOWN
          else raise ArgumentError, "invalid log level: #{severity}"
          end
        end
    end
  end
end

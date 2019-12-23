# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"
require "concurrent"
require "fiber"

module ActiveSupport
  module LoggerThreadSafeLevel # :nodoc:
    extend ActiveSupport::Concern

    included do
      cattr_accessor :local_levels, default: Concurrent::Map.new(initial_capacity: 2), instance_accessor: false
    end

    Logger::Severity.constants.each do |severity|
      class_eval(<<-EOT, __FILE__, __LINE__ + 1)
        def #{severity.downcase}?                # def debug?
          Logger::#{severity} >= level           #   DEBUG >= level
        end                                      # end
      EOT
    end

    def after_initialize
      ActiveSupport::Deprecation.warn(
        "Logger don't need to call #after_initialize directly anymore. It will be deprecated without replacement in " \
        "Rails 6.1."
      )
    end

    def local_log_id
      Fiber.current.__id__
    end

    def local_level
      self.class.local_levels[local_log_id]
    end

    def local_level=(level)
      case level
      when Integer
        self.class.local_levels[local_log_id] = level
      when Symbol
        self.class.local_levels[local_log_id] = Logger::Severity.const_get(level.to_s.upcase)
      when nil
        self.class.local_levels.delete(local_log_id)
      else
        raise ArgumentError, "Invalid log level: #{level.inspect}"
      end
    end

    def level
      local_level || super
    end

    # Change the thread-local level for the duration of the given block.
    def log_at(level)
      old_local_level, self.local_level = local_level, level
      yield
    ensure
      self.local_level = old_local_level
    end

    # Redefined to check severity against #level, and thus the thread-local level, rather than +@level+.
    # FIXME: Remove when the minimum Ruby version supports overriding Logger#level.
    def add(severity, message = nil, progname = nil, &block) #:nodoc:
      severity ||= UNKNOWN
      progname ||= @progname

      return true if @logdev.nil? || severity < level

      if message.nil?
        if block_given?
          message  = yield
        else
          message  = progname
          progname = @progname
        end
      end

      @logdev.write \
        format_message(format_severity(severity), Time.now, progname, message)
    end
  end
end

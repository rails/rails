# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"
require "concurrent"

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
      Thread.current.__id__
    end

    def local_level
      self.class.local_levels[local_log_id]
    end

    def local_level=(level)
      if level
        self.class.local_levels[local_log_id] = level
      else
        self.class.local_levels.delete(local_log_id)
      end
    end

    def level
      local_level || super
    end

    def add(severity, message = nil, progname = nil, &block) # :nodoc:
      return true if @logdev.nil? || (severity || UNKNOWN) < level
      super
    end
  end
end

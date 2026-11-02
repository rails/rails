# :markup: markdown
# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/logger_thread_safe_level"

module ActiveSupport
  module LoggerSilence
    extend ActiveSupport::Concern

    @silencer = true

    class << self
      attr_accessor :silencer
    end

    module ClassMethods
      def silencer = LoggerSilence.silencer
      def silencer=(value)
        LoggerSilence.silencer = value
      end
    end

    included do
      include ActiveSupport::LoggerThreadSafeLevel
    end

    def silencer = LoggerSilence.silencer

    def silencer=(value)
      LoggerSilence.silencer = value
    end

    # Silences the logger for the duration of the block.
    def silence(severity = Logger::ERROR)
      silencer ? log_at(severity) { yield self } : yield(self)
    end
  end
end

# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/logger_thread_safe_level'

module LoggerSilence
  extend ActiveSupport::Concern

  included do
    ActiveSupport::Deprecation.warn(
      'Including LoggerSilence is deprecated and will be removed in Rails 6.1. ' \
      'Please use `ActiveSupport::LoggerSilence` instead'
    )

    include ActiveSupport::LoggerSilence
  end
end

module ActiveSupport
  module LoggerSilence
    extend ActiveSupport::Concern

    included do
      cattr_accessor :silencer, default: true
      include ActiveSupport::LoggerThreadSafeLevel
    end

    # Silences the logger for the duration of the block.
    def silence(severity = Logger::ERROR)
      silencer ? log_at(severity) { yield self } : yield(self)
    end
  end
end

# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"

module LoggerSilence
  extend ActiveSupport::Concern

  included do
    ActiveSupport::Deprecation.warn(
      "Including LoggerSilence is deprecated and will be removed in Rails 6.1. " \
      "Please use `ActiveSupport::LoggerSilence` instead"
    )

    include ActiveSupport::LoggerSilence
  end
end

module ActiveSupport
  module LoggerSilence
    extend ActiveSupport::Concern

    included do
      cattr_accessor :silencer, default: true
    end

    # Silences the logger for the duration of the block.
    def silence(temporary_level = Logger::ERROR)
      if silencer
        begin
          old_local_level            = local_level
          self.local_level           = temporary_level

          yield self
        ensure
          self.local_level = old_local_level
        end
      else
        yield self
      end
    end
  end
end

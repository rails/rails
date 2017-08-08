# frozen_string_literal: true

require_relative "concern"
require_relative "core_ext/module/attribute_accessors"
require "concurrent"

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

# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"

class Time
  silence_redefinition_of_method :to_time

  # Return +self+.
  def to_time
    self
  end
end

# frozen_string_literal: true

require "active_support/core_ext/date_and_time/compatibility"
require "active_support/core_ext/module/redefine_method"

class Time
  include DateAndTime::Compatibility

  silence_redefinition_of_method :to_time

  # Return +self+.
  def to_time
    self
  end
end

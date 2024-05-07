# frozen_string_literal: true

require "active_support/core_ext/date_and_time/compatibility"
require "active_support/core_ext/module/redefine_method"

class DateTime
  include DateAndTime::Compatibility

  silence_redefinition_of_method :to_time

  # Return an instance of +Time+ with the same UTC offset
  # as +self+.
  def to_time
    getlocal(utc_offset)
  end
end

require 'active_support/core_ext/date_and_time/with_duration'

module ActiveSupport
  module DateOperators # :nodoc:
    include DateAndTime::WithDuration

    # Allow Date to be compared with Time by converting to DateTime and relying on the <=> from there.
    def <=>(other)
      if other.is_a?(Time)
        self.to_datetime <=> other
      else
        super
      end
    end
  end
end

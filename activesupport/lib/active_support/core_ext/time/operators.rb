require 'active_support/core_ext/date_and_time/with_duration'

module ActiveSupport
  module TimeOperators # :nodoc:
    include DateAndTime::WithDuration

    # Layers additional behavior on Time#<=> so that DateTime and ActiveSupport::TimeWithZone instances
    # can be chronologically compared with a Time
    def <=>(other)
      # we're avoiding Time#to_datetime and Time#to_time because they're expensive
      if other.class == Time
        super
      elsif other.is_a?(Time)
        super(other.to_time)
      else
        to_datetime <=> other
      end
    end

    # Layers additional behavior on Time#eql? so that ActiveSupport::TimeWithZone instances
    # can be eql? to an equivalent Time
    def eql?(other)
      # if other is an ActiveSupport::TimeWithZone, coerce a Time instance from it so we can do eql? comparison
      other = other.comparable_time if other.respond_to?(:comparable_time)
      super
    end

    # Time#- can also be used to determine the number of seconds between two Time instances.
    # We're layering on additional behavior so that ActiveSupport::TimeWithZone instances
    # are coerced into values that Time#- will recognize
    def -(other)
      other = other.comparable_time if other.respond_to?(:comparable_time)
      other.is_a?(DateTime) ? to_f - other.to_f : super
    end
  end
end

require 'date'
require 'active_support/core_ext/time/zones'

class Date
  # Converts Date to a TimeWithZone in the current zone if Time.zone_default is set,
  # otherwise converts Date to a Time via Date#to_time
  def to_time_in_current_zone
    if ::Time.zone_default
      ::Time.zone.local(year, month, day)
    else
      to_time
    end
  end

  # Ruby 1.9 has Date#xmlschema which converts to a string without the time component.
  remove_method :xmlschema if instance_methods.include?(:xmlschema)

  def xmlschema
    to_time_in_current_zone.xmlschema
  end
end

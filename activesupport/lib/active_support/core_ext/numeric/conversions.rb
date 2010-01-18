module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Numeric #:nodoc:
      module Conversions
        # Assumes self represents an offset from UTC in seconds (as returned from Time#utc_offset)
        # and turns this into an +HH:MM formatted string. Example:
        #
        #   -21_600.to_utc_offset_s   # => "-06:00"
        def to_utc_offset_s(colon=true)
          seconds = self
          sign = (seconds < 0 ? '-' : '+')
          hours = seconds.abs / 3600
          minutes = (seconds.abs % 3600) / 60
          "%s%02d%s%02d" % [ sign, hours, colon ? ":" : "", minutes ]
        end
      end
    end
  end
end

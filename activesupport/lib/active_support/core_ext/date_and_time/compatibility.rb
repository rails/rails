module DateAndTime
  module Compatibility
    # If true, +to_time+ preserves the the timezone offset.
    #
    # NOTE: With Ruby 2.4+ the default for +to_time+ changed from
    # converting to the local system time to preserving the offset
    # of the receiver. For backwards compatibility we're overriding
    # this behavior but new apps will have an initializer that sets
    # this to true because the new behavior is preferred.
    mattr_accessor(:preserve_timezone, instance_writer: false) { false }

    def to_time
      preserve_timezone ? getlocal(utc_offset) : getlocal
    end
  end
end

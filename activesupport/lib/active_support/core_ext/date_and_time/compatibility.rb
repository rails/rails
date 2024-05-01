# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module DateAndTime
  module Compatibility
    # Change the output of <tt>ActiveSupport::TimeZone.utc_to_local</tt>.
    #
    # When +true+, it returns local times with a UTC offset, with +false+ local
    # times are returned as UTC.
    #
    #   # Given this zone:
    #   zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    #
    #   # With `utc_to_local_returns_utc_offset_times = false`, local time is converted to UTC:
    #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 UTC
    #
    #   # With `utc_to_local_returns_utc_offset_times = true`, local time is returned with UTC offset:
    #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 -0500
    mattr_accessor :utc_to_local_returns_utc_offset_times, instance_writer: false, default: false

    def self.preserve_timezone
      ActiveSupport.deprecator.warn(
        "`DateAndTime::Compatibility.preserve_timezone` has been deprecated and will be removed in Rails 7.3."
      )
    end

    def self.preserve_timezone=(value)
      ActiveSupport.deprecator.warn(
        "`DateAndTime::Compatibility.preserve_timezone=` has been deprecated and will be removed in Rails 7.3."
      )
    end
  end
end

# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module DateAndTime
  module Compatibility
    # If true, +to_time+ preserves the timezone offset of receiver.
    #
    # NOTE: With Ruby 2.4+ the default for +to_time+ changed from
    # converting to the local system time, to preserving the offset
    # of the receiver. For backwards compatibility we're overriding
    # this behavior, but new apps will have an initializer that sets
    # this to true, because the new behavior is preferred.
    mattr_accessor :preserve_timezone, instance_writer: false, default: false

    # Active Support now uses TZInfo 2, but can act as if using TZInfo 1.
    #
    # Changes the interface of <tt>ActiveSupport::TimeZone</tt>/<tt>ActiveSupport::TimeWithZone</tt>.
    #
    # <tt>ActiveSupport::TimeZone#utc_to_local</tt> returns local times with
    # UTC offset, instead of returning local times as UTC. For example:
    #
    #   # Given this zone:
    #   zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    #
    #   # With `use_tzinfo2_format = false`, local time is converted to UTC:
    #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 UTC
    #
    #   # With `use_tzinfo2_format = true`, local time is returned with UTC offset:
    #   zone.utc_to_local(Time.utc(2000, 1)) # => 1999-12-31 19:00:00 -0500
    mattr_accessor :use_tzinfo2_format, instance_writer: false, default: false
  end
end

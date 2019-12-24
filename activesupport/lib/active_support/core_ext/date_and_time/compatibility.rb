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

    # ActiveSupport now uses TZInfo 2, but you may want it to act as if
    # using TZInfo 1.
    #
    # This setting causes one change to the interface of TimeZone/TimeWithZone.
    # TimeZone#utc_to_local will now return local times with the appropriate
    # UTC offset (instead of returning local times as UTC). For example,
    # with `tzinfo_compatibility_version = 1`,
    #
    #   zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    #   zone.utc_to_local(Time.utc(2000, 1))
    #   #=> 1999-12-31 19:00:00 UTC
    #
    # .. and with `tzinfo_compatibility_version = 2`,
    #
    #   zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    #   zone.utc_to_local(Time.utc(2000, 1))
    #   #=> 1999-12-31 19:00:00 -0500
    #
    # Legal values are the strings '1' and '2'. All other values will raise
    # an error.
    mattr_accessor :tzinfo_compatibility_version,
      instance_writer: false,
      default: "1"
  end
end

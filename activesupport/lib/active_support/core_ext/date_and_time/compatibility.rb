# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/module/redefine_method"

module DateAndTime
  module Compatibility
    # If true, +to_time+ preserves the timezone offset of receiver.
    #
    # NOTE: With Ruby 2.4+ the default for +to_time+ changed from
    # converting to the local system time, to preserving the offset
    # of the receiver. For backwards compatibility we're overriding
    # this behavior, but new apps will have an initializer that sets
    # this to true, because the new behavior is preferred.
    mattr_accessor :preserve_timezone, instance_accessor: false, default: nil

    singleton_class.silence_redefinition_of_method :preserve_timezone

    #--
    # This re-implements the behaviour of the mattr_reader, instead
    # of prepending on to it, to avoid overcomplicating a module that
    # is in turn included in several places. This will all go away in
    # Rails 8.0 anyway.
    def self.preserve_timezone # :nodoc:
      if @@preserve_timezone.nil?
        # Only warn once, the first time the value is used (which should
        # be the first time #to_time is called).
        ActiveSupport.deprecator.warn(
          "`to_time` will always preserve the receiver timezone rather than system local time in Rails 8.1." \
          "To opt in to the new behavior, set `config.active_support.to_time_preserves_timezone = :zone`."
        )

        @@preserve_timezone = false
      end

      @@preserve_timezone
    end

    def preserve_timezone # :nodoc:
      Compatibility.preserve_timezone
    end

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
  end
end

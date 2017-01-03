require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/remove_method'

module DateAndTime
  module Compatibility
    # If true, +to_time+ preserves the timezone offset of receiver.
    #
    # NOTE: With Ruby 2.4+ the default for +to_time+ changed from
    # converting to the local system time, to preserving the offset
    # of the receiver. For backwards compatibility we're overriding
    # this behavior, but new apps will have an initializer that sets
    # this to true, because the new behavior is preferred.
    mattr_accessor(:preserve_timezone, instance_writer: false) { false }

    def self.included(base)
      base.class_eval do
        remove_possible_method :to_time

        def to_time
          if preserve_timezone
            @_to_time_with_instance_offset ||= getlocal(utc_offset)
          else
            @_to_time_with_system_offset ||= getlocal
          end
        end
      end
    end
  end
end

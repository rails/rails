# frozen_string_literal: true

require 'active_support/time_with_zone'
require 'active_support/deprecation'

module ActiveSupport
  module IncludeTimeWithZone #:nodoc:
    # Extends the default Range#include? to support ActiveSupport::TimeWithZone.
    #
    #   (1.hour.ago..1.hour.from_now).include?(Time.current) # => true
    #
    def include?(value)
      if self.begin.is_a?(TimeWithZone) || self.end.is_a?(TimeWithZone)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Using `Range#include?` to check the inclusion of a value in
          a date time range is deprecated.
          It is recommended to use `Range#cover?` instead of `Range#include?` to
          check the inclusion of a value in a date time range.
        MSG
        cover?(value)
      else
        super
      end
    end
  end
end

Range.prepend(ActiveSupport::IncludeTimeWithZone)

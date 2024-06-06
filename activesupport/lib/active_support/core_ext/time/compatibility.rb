# frozen_string_literal: true

require "active_support/core_ext/date_and_time/compatibility"
require "active_support/core_ext/module/redefine_method"

class Time
  include DateAndTime::Compatibility

  silence_redefinition_of_method :to_time

  # Either return +self+ or the time in the local system timezone depending
  # on the setting of +ActiveSupport.to_time_preserves_timezone+.
  def to_time
    preserve_timezone ? self : getlocal
  end

  def preserve_timezone # :nodoc:
    active_support_local_zone == zone || super
  end

  private
    @@active_support_local_tz = nil

    def active_support_local_zone
      @@active_support_local_zone = nil if @@active_support_local_tz != ENV["TZ"]
      @@active_support_local_zone ||=
        begin
          @@active_support_local_tz = ENV["TZ"]
          Time.new.zone
        end
    end
end

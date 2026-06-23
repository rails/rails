# frozen_string_literal: true

require "time"
require "active_support/inflector/methods"
require "active_support/values/time_zone"
require "active_support/time_formats"

class Time
  include ActiveSupport::Deprecation::DeprecatedConstantAccessor

  deprecate_constant :DATE_FORMATS, "ActiveSupport::TimeFormats::DEPRECATED_LIST",
    deprecator: ActiveSupport.deprecator,
    message: "Time::DATE_FORMATS is deprecated, to register custom time formats use ActiveSupport::TimeFormats.register"

  # Converts to a formatted string. See DATE_FORMATS for built-in formats.
  #
  # This method is aliased to <tt>to_formatted_s</tt>.
  #
  #   time = Time.now                    # => 2007-01-18 06:10:17 -06:00
  #
  #   time.to_fs(:time)                  # => "06:10"
  #   time.to_formatted_s(:time)         # => "06:10"
  #
  #   time.to_fs(:db)           # => "2007-01-18 06:10:17"
  #   time.to_fs(:number)       # => "20070118061017"
  #   time.to_fs(:short)        # => "18 Jan 06:10"
  #   time.to_fs(:long)         # => "January 18, 2007 06:10"
  #   time.to_fs(:long_ordinal) # => "January 18th, 2007 06:10"
  #   time.to_fs(:rfc822)       # => "Thu, 18 Jan 2007 06:10:17 -0600"
  #   time.to_fs(:rfc2822)       # => "Thu, 18 Jan 2007 06:10:17 -0600"
  #   time.to_fs(:iso8601)      # => "2007-01-18T06:10:17-06:00"
  #
  # == Adding your own time formats to +to_fs+
  # You can add your own formats using the +ActiveSupport::TimeFormats.register+ method.
  # Use the format name as the name and either a strftime string
  # or Proc instance that takes a time argument as the value.
  #
  #   # config/initializers/time_formats.rb
  #   ActiveSupport::TimeFormats.register(:month_and_year, '%B %Y')
  #   ActiveSupport::TimeFormats.register(:short_ordinal, ->(time) { time.strftime("%B #{time.day.ordinalize}") })
  def to_fs(format = :default)
    if formatter = ::ActiveSupport::TimeFormats.lookup(format)
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    else
      to_s
    end
  end
  alias_method :to_formatted_s, :to_fs

  # Returns a formatted string of the offset from UTC, or an alternative
  # string if the time zone is already UTC.
  #
  #   Time.local(2000).formatted_offset        # => "-06:00"
  #   Time.local(2000).formatted_offset(false) # => "-0600"
  def formatted_offset(colon = true, alternate_utc_string = nil)
    utc? && alternate_utc_string || ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset, colon)
  end

  # Aliased to +xmlschema+ for compatibility with +DateTime+
  alias_method :rfc3339, :xmlschema
end

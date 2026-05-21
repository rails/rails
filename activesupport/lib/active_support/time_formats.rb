# frozen_string_literal: true

module ActiveSupport
  module TimeFormats
    @list = {
      db: "%Y-%m-%d %H:%M:%S",
      inspect: "%Y-%m-%d %H:%M:%S.%9N %z",
      number: "%Y%m%d%H%M%S",
      nsec: "%Y%m%d%H%M%S%9N",
      usec: "%Y%m%d%H%M%S%6N",
      time: "%H:%M",
      short: "%d %b %H:%M",
      long: "%B %d, %Y %H:%M",
      long_ordinal: lambda { |time|
        day_format = ActiveSupport::Inflector.ordinalize(time.day)
        time.strftime("%B #{day_format}, %Y %H:%M")
      },
      rfc822: lambda { |time|
        offset_format = time.formatted_offset(false)
        time.strftime("%a, %d %b %Y %H:%M:%S #{offset_format}")
      },
      rfc2822: lambda { |time| time.rfc2822 },
      iso8601: lambda { |time| time.iso8601 }
    }.freeze

    singleton_class.attr_reader :list # :nodoc:

    DEPRECATED_LIST = @list.dup # :nodoc:

    def self.lookup(format) # :nodoc:
      @list[format] || DEPRECATED_LIST[format]
    end

    # Registers a new date format for formatting Time instances.
    # See +Time::DATE_FORMATS+ for built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end
  end
end

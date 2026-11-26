# frozen_string_literal: true

require "active_support/ractors"
require "active_support/deprecated_formats"

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
      long_ordinal: ActiveSupport::Ractors.shareable_lambda { |time|
        day_format = ActiveSupport::Inflector.ordinalize(time.day)
        time.strftime("%B #{day_format}, %Y %H:%M")
      },
      rfc822: ActiveSupport::Ractors.shareable_lambda { |time|
        offset_format = time.formatted_offset(false)
        time.strftime("%a, %d %b %Y %H:%M:%S #{offset_format}")
      },
      rfc2822: ActiveSupport::Ractors.shareable_lambda { |time| time.rfc2822 },
      iso8601: ActiveSupport::Ractors.shareable_lambda { |time| time.iso8601 }
    }.freeze

    singleton_class.attr_reader :list # :nodoc:

    # Registers a new date format for formatting Time instances.
    # See Time#to_fs for examples of built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end

    # When removing Time::DATE_FORMATS, delete the state below and the
    # `deprecated_formats` require. Reduce `lookup` to `@list[format]`.
    @builtin_formats = @shared_deprecated_list = @list

    DEPRECATED_LIST = DeprecatedFormats.build(@builtin_formats) do |snapshot| # :nodoc:
      @shared_deprecated_list = snapshot
    end

    def self.lookup(format) # :nodoc:
      formatter = @list[format]
      return formatter if formatter != @builtin_formats[format]

      (Ractors.main? ? DEPRECATED_LIST : @shared_deprecated_list)[format]
    end
  end
end

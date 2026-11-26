# frozen_string_literal: true

require "active_support/ractors"
require "active_support/deprecated_formats"

module ActiveSupport
  module DateFormats
    @list = {
      short: "%d %b",
      long: "%B %d, %Y",
      db: "%Y-%m-%d",
      inspect: "%Y-%m-%d",
      number: "%Y%m%d",
      long_ordinal: Ractors.shareable_lambda { |date|
        day_format = ActiveSupport::Inflector.ordinalize(date.day)
        date.strftime("%B #{day_format}, %Y") # => "April 25th, 2007"
      },
      rfc822: "%d %b %Y",
      rfc2822: "%d %b %Y",
      iso8601: Ractors.shareable_lambda { |date| date.iso8601 }
    }.freeze

    singleton_class.attr_reader :list # :nodoc:

    # Registers a new date format for formatting Date instances.
    # See Date#to_fs for examples of built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end

    # When removing Date::DATE_FORMATS, delete the state below and the
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

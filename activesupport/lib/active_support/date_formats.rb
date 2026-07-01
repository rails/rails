# frozen_string_literal: true

module ActiveSupport
  module DateFormats
    @list = {
      short: "%d %b",
      long: "%B %d, %Y",
      db: "%Y-%m-%d",
      inspect: "%Y-%m-%d",
      number: "%Y%m%d",
      long_ordinal: lambda { |date|
        day_format = ActiveSupport::Inflector.ordinalize(date.day)
        date.strftime("%B #{day_format}, %Y") # => "April 25th, 2007"
      },
      rfc822: "%d %b %Y",
      rfc2822: "%d %b %Y",
      iso8601: lambda { |date| date.iso8601 }
    }.freeze

    singleton_class.attr_reader :list # :nodoc:

    DEPRECATED_LIST = @list.dup # :nodoc:

    def self.lookup(format) # :nodoc:
      @list[format] || DEPRECATED_LIST[format]
    end

    # Registers a new date format for formatting Date instances.
    # See +Date::DATE_FORMATS+ for built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end
  end
end

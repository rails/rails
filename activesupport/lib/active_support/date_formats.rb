# frozen_string_literal: true

require "active_support/core_ext/date/conversions"

module ActiveSupport
  module DateFormats
    @list = Date::DATE_FORMATS.dup.freeze
    @deprecated_list = Date::DATE_FORMATS
    Date.deprecate_constant :DATE_FORMATS

    def self.lookup(format) # :nodoc:
      @list[format] || @deprecated_list[format]
    end

    # Registers a new date format for formatting `Date` instances.
    # See +Date::DATE_FORMATS+ for built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end
  end
end

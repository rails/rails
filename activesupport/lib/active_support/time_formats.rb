# frozen_string_literal: true

require "active_support/core_ext/time/conversions"

module ActiveSupport
  module TimeFormats
    @list = Time::DATE_FORMATS.dup.freeze
    @deprecated_list = Time::DATE_FORMATS
    Time.deprecate_constant :DATE_FORMATS

    # :nodoc:
    def self.lookup(format)
      @list[format] || @deprecated_list[format]
    end

    # Registers a new date format for formatting `Time` instances.
    # See +Time::DATE_FORMATS+ for built-in formats.
    # Use the format name as the name and either a strftime string or
    # Proc instance that takes a date argument as the value.
    def self.register(name, format)
      @list = @list.merge(name => format).freeze
    end
  end
end

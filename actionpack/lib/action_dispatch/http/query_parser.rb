# frozen_string_literal: true

require "uri"
require "rack"

module ActionDispatch
  class QueryParser
    DEFAULT_SEP = /& */n
    COMMON_SEP = { ";" => /; */n, ";," => /[;,] */n, "&" => /& */n, "&;" => /[&;] */n }

    def self.strict_query_string_separator
      ActionDispatch.deprecator.warn <<~MSG
        The `strict_query_string_separator` configuration is deprecated have no effect and will be removed in Rails 8.2.
      MSG
      @strict_query_string_separator
    end

    def self.strict_query_string_separator=(value)
      ActionDispatch.deprecator.warn <<~MSG
        The `strict_query_string_separator` configuration is deprecated have no effect and will be removed in Rails 8.2.
      MSG
      @strict_query_string_separator = value
    end

    #--
    # Note this departs from WHATWG's specified parsing algorithm by
    # giving a nil value for keys that do not use '='. Callers that need
    # the standard's interpretation can use `v.to_s`.
    def self.each_pair(s, separator = nil)
      return enum_for(:each_pair, s, separator) unless block_given?

      s ||= ""

      splitter =
        if separator
          COMMON_SEP[separator] || /[#{separator}] */n
        else
          DEFAULT_SEP
        end

      s.split(splitter).each do |part|
        next if part.empty?

        k, v = part.split("=", 2)

        k = URI.decode_www_form_component(k)
        v &&= URI.decode_www_form_component(v)

        yield k, v
      end

      nil
    end
  end
end

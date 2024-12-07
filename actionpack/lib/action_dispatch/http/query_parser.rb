# frozen_string_literal: true

require "uri"
require "rack"

module ActionDispatch
  class QueryParser
    DEFAULT_SEP = /& */n
    COMPAT_SEP = /[&;] */n
    COMMON_SEP = { ";" => /; */n, ";," => /[;,] */n, "&" => /& */n, "&;" => /[&;] */n }

    cattr_accessor :strict_query_string_separator

    SEMICOLON_COMPAT = defined?(::Rack::QueryParser::DEFAULT_SEP) && ::Rack::QueryParser::DEFAULT_SEP.to_s.include?(";")

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
        elsif strict_query_string_separator
          DEFAULT_SEP
        elsif SEMICOLON_COMPAT && s.include?(";")
          if strict_query_string_separator.nil?
            ActionDispatch.deprecator.warn("Using semicolon as a query string separator is deprecated and will not be supported in Rails 8.1 or Rack 3.0. Use `&` instead.")
          end
          COMPAT_SEP
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

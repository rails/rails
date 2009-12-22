# encoding: utf-8
require 'active_support/core_ext/module/delegation'
require 'active_support/deprecation'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    class << self
      delegate :encode, :to => :'ActiveSupport::JSON::Encoding'
    end

    module Encoding #:nodoc:
      class CircularReferenceError < StandardError
      end

      ESCAPED_CHARS = {
        "\x00" => '\u0000', "\x01" => '\u0001', "\x02" => '\u0002',
        "\x03" => '\u0003', "\x04" => '\u0004', "\x05" => '\u0005',
        "\x06" => '\u0006', "\x07" => '\u0007', "\x0B" => '\u000B',
        "\x0E" => '\u000E', "\x0F" => '\u000F', "\x10" => '\u0010',
        "\x11" => '\u0011', "\x12" => '\u0012', "\x13" => '\u0013',
        "\x14" => '\u0014', "\x15" => '\u0015', "\x16" => '\u0016',
        "\x17" => '\u0017', "\x18" => '\u0018', "\x19" => '\u0019',
        "\x1A" => '\u001A', "\x1B" => '\u001B', "\x1C" => '\u001C',
        "\x1D" => '\u001D', "\x1E" => '\u001E', "\x1F" => '\u001F',
        "\010" =>  '\b',
        "\f"   =>  '\f',
        "\n"   =>  '\n',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026' }

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        attr_accessor :escape_regex
        attr_reader :escape_html_entities_in_json

        def escape_html_entities_in_json=(value)
          self.escape_regex = \
            if @escape_html_entities_in_json = value
              /[\x00-\x1F"\\><&]/
            else
              /[\x00-\x1F"\\]/
            end
        end

        def escape(string)
          string = string.dup.force_encoding(::Encoding::BINARY) if string.respond_to?(:force_encoding)
          json = string.
            gsub(escape_regex) { |s| ESCAPED_CHARS[s] }.
            gsub(/([\xC0-\xDF][\x80-\xBF]|
                   [\xE0-\xEF][\x80-\xBF]{2}|
                   [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
            s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/n, '\\\\u\&')
          }
          %("#{json}")
        end

        # Converts a Ruby object into a JSON string.
        def encode(value, options = nil)
          options = {} unless Hash === options
          seen = (options[:seen] ||= [])
          raise CircularReferenceError, 'object references itself' if seen.include?(value)
          seen << value
          value.to_json(options)
        ensure
          seen.pop
        end
      end

      self.escape_html_entities_in_json = true
    end

    CircularReferenceError = Deprecation::DeprecatedConstantProxy.new('ActiveSupport::JSON::CircularReferenceError', Encoding::CircularReferenceError)
  end
end

# Hack to load json gem first so we can overwrite its to_json.
begin
  require 'json'
rescue LoadError
end

require 'active_support/json/variable'
require 'active_support/json/encoders/date'
require 'active_support/json/encoders/date_time'
require 'active_support/json/encoders/enumerable'
require 'active_support/json/encoders/false_class'
require 'active_support/json/encoders/hash'
require 'active_support/json/encoders/nil_class'
require 'active_support/json/encoders/numeric'
require 'active_support/json/encoders/object'
require 'active_support/json/encoders/regexp'
require 'active_support/json/encoders/string'
require 'active_support/json/encoders/symbol'
require 'active_support/json/encoders/time'
require 'active_support/json/encoders/true_class'

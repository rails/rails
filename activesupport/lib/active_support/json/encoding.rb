#encoding: us-ascii

require 'active_support/core_ext/object/json'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :encode_big_decimal_as_string, :encode_big_decimal_as_string=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # Dumps objects in JSON (JavaScript Object Notation).
    # See www.json.org for more info.
    #
    #   ActiveSupport::JSON.encode({ team: 'rails', players: '36' })
    #   # => "{\"team\":\"rails\",\"players\":\"36\"}"
    def self.encode(value, options = nil)
      Encoding::Encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class Encoder
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        def encode(value)
          value.as_json(options.dup).encode_json(self)
        end

        def escape(string)
          Encoding.escape(string)
        end
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
        "\xe2\x80\xa8" => '\u2028',
        "\xe2\x80\xa9" => '\u2029',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026',
        "#{0xe2.chr}#{0x80.chr}#{0xa8.chr}" => '\u2028',
        "#{0xe2.chr}#{0x80.chr}#{0xa9.chr}" => '\u2029',
        }

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back
        # to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        # If false, serializes BigDecimal objects as numeric instead of wrapping
        # them in a string.
        attr_accessor :encode_big_decimal_as_string

        attr_accessor :escape_regex
        attr_reader :escape_html_entities_in_json

        def escape_html_entities_in_json=(value)
          self.escape_regex = \
            if @escape_html_entities_in_json = value
              /\xe2\x80\xa8|\xe2\x80\xa9|[\x00-\x1F"\\><&]/
            else
              /\xe2\x80\xa8|\xe2\x80\xa9|[\x00-\x1F"\\]/
            end
        end

        def escape(string)
          string = string.encode(::Encoding::UTF_8, :undef => :replace).force_encoding(::Encoding::BINARY)
          json = string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }
          json = %("#{json}")
          json.force_encoding(::Encoding::UTF_8)
          json
        end

        # Deprecate CircularReferenceError
        def const_missing(name)
          if name == :CircularReferenceError
            message = "The JSON encoder in Rails 4.1 no longer offers protection from circular references. " \
                      "You are seeing this warning because you are rescuing from (or otherwise referencing) " \
                      "ActiveSupport::Encoding::CircularReferenceError. In the future, this error will be " \
                      "removed from Rails. You should remove these rescue blocks from your code and ensure " \
                      "that your data structures are free of circular references so they can be properly " \
                      "serialized into JSON.\n\n" \
                      "For example, the following Hash contains a circular reference to itself:\n" \
                      "   h = {}\n" \
                      "   h['circular'] = h\n" \
                      "In this case, calling h.to_json would not work properly."

            ActiveSupport::Deprecation.warn message

            SystemStackError
          else
            super
          end
        end
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = true
      self.encode_big_decimal_as_string  = true
    end
  end
end

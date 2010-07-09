require 'active_support/core_ext/object/to_json'
require 'active_support/core_ext/module/delegation'
require 'active_support/deprecation'
require 'active_support/json/variable'

require 'bigdecimal'
require 'active_support/core_ext/big_decimal/conversions' # for #to_s
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/object/instance_variables'
require 'time'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/date/conversions'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
    def self.encode(value, options = nil)
      Encoding::Encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class CircularReferenceError < StandardError; end

      class Encoder
        attr_reader :options

        def initialize(options = nil)
          @options = options
          @seen = []
        end

        def encode(value)
          check_for_circular_references(value) do
            value.as_json(options).encode_json(self)
          end
        end

        def escape(string)
          Encoding.escape(string)
        end

        private
          def check_for_circular_references(value)
            if @seen.any? { |object| object.equal?(value) }
              raise CircularReferenceError, 'object references itself'
            end
            @seen.unshift value
            yield
          ensure
            @seen.shift
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
          if string.respond_to?(:force_encoding)
            string = string.encode(::Encoding::UTF_8, :undef => :replace).force_encoding(::Encoding::BINARY)
          end
          json = string.
            gsub(escape_regex) { |s| ESCAPED_CHARS[s] }.
            gsub(/([\xC0-\xDF][\x80-\xBF]|
                   [\xE0-\xEF][\x80-\xBF]{2}|
                   [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
            s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/n, '\\\\u\&')
          }
          json = %("#{json}")
          json.force_encoding(::Encoding::UTF_8) if json.respond_to?(:force_encoding)
          json
        end
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = false
    end

    CircularReferenceError = Deprecation::DeprecatedConstantProxy.new('ActiveSupport::JSON::CircularReferenceError', Encoding::CircularReferenceError)
  end
end

class Object
  def as_json(options = nil) #:nodoc:
    if respond_to?(:to_hash)
      to_hash
    else
      instance_values
    end
  end
end

class TrueClass
  AS_JSON = ActiveSupport::JSON::Variable.new('true').freeze
  def as_json(options = nil) AS_JSON end #:nodoc:
end

class FalseClass
  AS_JSON = ActiveSupport::JSON::Variable.new('false').freeze
  def as_json(options = nil) AS_JSON end #:nodoc:
end

class NilClass
  AS_JSON = ActiveSupport::JSON::Variable.new('null').freeze
  def as_json(options = nil) AS_JSON end #:nodoc:
end

class String
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) encoder.escape(self) end #:nodoc:
end

class Symbol
  def as_json(options = nil) to_s end #:nodoc:
end

class Numeric
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) to_s end #:nodoc:
end

class BigDecimal
  # A BigDecimal would be naturally represented as a JSON number. Most libraries,
  # however, parse non-integer JSON numbers directly as floats. Clients using
  # those libraries would get in general a wrong number and no way to recover
  # other than manually inspecting the string with the JSON code itself.
  #
  # That's why a JSON string is returned. The JSON literal is not numeric, but if
  # the other end knows by contract that the data is supposed to be a BigDecimal,
  # it still has the chance to post-process the string and get the real value.
  def as_json(options = nil) to_s end #:nodoc:
end

class Regexp
  def as_json(options = nil) to_s end #:nodoc:
end

module Enumerable
  def as_json(options = nil) to_a end #:nodoc:
end

class Array
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) "[#{map { |v| encoder.encode(v) } * ','}]" end #:nodoc:
end

class Hash
  def as_json(options = nil) #:nodoc:
    if options
      if attrs = options[:only]
        slice(*Array.wrap(attrs))
      elsif attrs = options[:except]
        except(*Array.wrap(attrs))
      else
        self
      end
    else
      self
    end
  end

  def encode_json(encoder)
    "{#{map { |k,v| "#{encoder.encode(k.to_s)}:#{encoder.encode(v)}" } * ','}}"
  end
end

class Time
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      %(#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
    end
  end
end

class Date
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      strftime("%Y-%m-%d")
    else
      strftime("%Y/%m/%d")
    end
  end
end

class DateTime
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      strftime('%Y/%m/%d %H:%M:%S %z')
    end
  end
end

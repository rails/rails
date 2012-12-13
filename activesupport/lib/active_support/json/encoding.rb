require 'active_support/core_ext/object/to_json'
require 'active_support/core_ext/module/delegation'
require 'active_support/json/variable'
require 'active_support/ordered_hash'

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
require 'set'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[T \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
    def self.encode(value, options = nil)
      Encoding::Encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class CircularReferenceError < StandardError; end

      class Encoder
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
          @seen = Set.new
        end

        def encode(value, use_options = true)
          check_for_circular_references(value) do
            jsonified = use_options ? value.as_json(options_for(value)) : value.as_json
            jsonified.encode_json(self)
          end
        end

        # like encode, but only calls as_json, without encoding to string
        def as_json(value, use_options = true)
          check_for_circular_references(value) do
            use_options ? value.as_json(options_for(value)) : value.as_json
          end
        end

        def options_for(value)
          if value.is_a?(Array) || value.is_a?(Hash)
            # hashes and arrays need to get encoder in the options, so that they can detect circular references
            options.merge(:encoder => self)
          else
            options.dup
          end
        end

        def escape(string)
          Encoding.escape(string)
        end

        private
          def check_for_circular_references(value)
            unless @seen.add?(value.__id__)
              raise CircularReferenceError, 'object references itself'
            end
            yield
          ensure
            @seen.delete(value.__id__)
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
          json = string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }
          json = %("#{json}")
          json.force_encoding(::Encoding::UTF_8) if json.respond_to?(:force_encoding)
          json
        end
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = false
    end
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

class Struct #:nodoc:
  def as_json(options = nil)
    Hash[members.zip(values)]
  end
end

class TrueClass
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) to_s end #:nodoc:
end

class FalseClass
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) to_s end #:nodoc:
end

class NilClass
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) 'null' end #:nodoc:
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
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    # use encoder as a proxy to call as_json on all elements, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::Encoder.new(options)
    map { |v| encoder.as_json(v, options) }
  end

  def encode_json(encoder) #:nodoc:
    # we assume here that the encoder has already run as_json on self and the elements, so we run encode_json directly
    "[#{map { |v| v.encode_json(encoder) } * ','}]"
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
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

    # use encoder as a proxy to call as_json on all values in the subset, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::Encoder.new(options)
    result = self.is_a?(ActiveSupport::OrderedHash) ? ActiveSupport::OrderedHash : Hash
    result[subset.map { |k, v| [k.to_s, encoder.as_json(v, options)] }]
  end

  def encode_json(encoder)
    # values are encoded with use_options = false, because we don't want hash representations from ActiveModel to be
    # processed once again with as_json with options, as this could cause unexpected results (i.e. missing fields);

    # on the other hand, we need to run as_json on the elements, because the model representation may contain fields
    # like Time/Date in their original (not jsonified) form, etc.

    "{#{map { |k,v| "#{encoder.encode(k.to_s)}:#{encoder.encode(v, false)}" } * ','}}"
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

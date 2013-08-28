#encoding: us-ascii

require 'active_support/core_ext/object/to_json'
require 'active_support/core_ext/module/delegation'

require 'bigdecimal'
require 'active_support/core_ext/big_decimal/conversions' # for #to_s
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/object/instance_variables'
require 'time'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/date/conversions'
require 'json'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :encode_big_decimal_as_string, :encode_big_decimal_as_string=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[T \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

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
          json = ::JSON.generate(jsonify(value, true), max_nesting: false, quirks_mode: true)

          if Encoding.escape_html_entities_in_json
            escape_regex = /[><&\u2028\u2029]/
          else
            escape_regex = /[\u2028\u2029]/
          end

          json.gsub(escape_regex, Encoding::ESCAPED_CHARS)
        end

        def jsonify(value, use_options = false)
          if value.respond_to?(:as_json)
            value = value.as_json(use_options ? options.dup : nil)
          end

          case value
          when TrueClass, FalseClass, NilClass, String, Numeric
            jsonify_scalar(value)
          when Hash
            jsonify_hash(value)
          when Array
            jsonify_array(value)
          else
            jsonify_other(value)
          end
        end

        protected
          def jsonify_scalar(value)
            value
          end

          def jsonify_hash(value)
            Hash[value.map { |k, v| [self.jsonify(k.to_s), self.jsonify(v)] }]
          end

          def jsonify_array(value)
            value.map { |item| self.jsonify(item) }
          end

          def jsonify_other(value)
            raise TypeError, "Don't know how to jsonify #{value.inspect}"
          end
      end

      ESCAPED_CHARS = {
        '>'      => '\u003E',
        '<'      => '\u003C',
        '&'      => '\u0026',
        "\u2028" => '\u2028',
        "\u2029" => '\u2029',
        }

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back
        # to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        # If false, serializes BigDecimal objects as numeric instead of wrapping
        # them in a string.
        attr_accessor :encode_big_decimal_as_string
        attr_accessor :escape_html_entities_in_json

        # Deprecate CircularReferenceError
        def const_missing(name)
          if name == :CircularReferenceError
            message = "Since Rails 4.1, the JSON encoder no longer offer protection from circular " \
                      "references. You should stop relying on ActiveSupport::Encoding::CircularReferenceError " \
                      "as it will be removed from Rails in future."

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
  def as_json(options = nil) #:nodoc:
    self
  end
end

class FalseClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class NilClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class String
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Symbol
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Numeric
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Float
  # Encoding Infinity or NaN to JSON should return "null". The default returns
  # "Infinity" or "NaN" which breaks parsing the JSON. E.g. JSON.parse('[NaN]').
  def as_json(options = nil) #:nodoc:
    finite? ? self : nil
  end
end

class BigDecimal
  # A BigDecimal would be naturally represented as a JSON number. Most libraries,
  # however, parse non-integer JSON numbers directly as floats. Clients using
  # those libraries would get in general a wrong number and no way to recover
  # other than manually inspecting the string with the JSON code itself.
  #
  # That's why a JSON string is returned. The JSON literal is not numeric, but
  # if the other end knows by contract that the data is supposed to be a
  # BigDecimal, it still has the chance to post-process the string and get the
  # real value.
  #
  # Use <tt>ActiveSupport.use_standard_json_big_decimal_format = true</tt> to
  # override this behavior.
  def as_json(options = nil) #:nodoc:
    if finite?
      ActiveSupport.encode_big_decimal_as_string ? to_s : self
    else
      nil
    end
  end

  def to_json(options = nil) #:nodoc:
    if finite?
      ActiveSupport.encode_big_decimal_as_string ? %("#{to_s}") : to_s
    else
      "null"
    end
  end
end

class Regexp
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

module Enumerable
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Range
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    map{ |v| v.as_json(options && options.dup) }
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    Hash[subset.map { |k, v| [k.to_s, v.as_json(options && options.dup)] }]
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

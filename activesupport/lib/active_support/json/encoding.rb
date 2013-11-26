require 'active_support/core_ext/object/json'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :json_encoder, :json_encoder=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # Dumps objects in JSON (JavaScript Object Notation).
    # See www.json.org for more info.
    #
    #   ActiveSupport::JSON.encode({ team: 'rails', players: '36' })
    #   # => "{\"team\":\"rails\",\"players\":\"36\"}"
    def self.encode(value, options = nil)
      Encoding.json_encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class JSONGemEncoder #:nodoc:
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        # Encode the given object into a JSON string
        def encode(value)
          stringify jsonify value.as_json(options.dup)
        end

        private
          # Rails does more escaping than the JSON gem natively does (we
          # escape \u2028 and \u2029 and optionally >, <, & to work around
          # certain browser problems).
          ESCAPED_CHARS = {
            "\u2028" => '\u2028',
            "\u2029" => '\u2029',
            '>'      => '\u003e',
            '<'      => '\u003c',
            '&'      => '\u0026',
            }

          ESCAPE_REGEX_WITH_HTML_ENTITIES = /[\u2028\u2029><&]/u
          ESCAPE_REGEX_WITHOUT_HTML_ENTITIES = /[\u2028\u2029]/u

          # This class wraps all the strings we see and does the extra escaping
          class EscapedString < String
            def to_json(*)
              if Encoding.escape_html_entities_in_json
                super.gsub ESCAPE_REGEX_WITH_HTML_ENTITIES, ESCAPED_CHARS
              else
                super.gsub ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, ESCAPED_CHARS
              end
            end
          end

          # Mark these as private so we don't leak encoding-specific constructs
          private_constant :ESCAPED_CHARS, :ESCAPE_REGEX_WITH_HTML_ENTITIES, 
            :ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, :EscapedString

          # Recursively turn the given object into a "jsonified" Ruby data structure
          # that the JSON gem understands - i.e. we want only Hash, Array, String,
          # Numeric, true, false and nil in the final tree. Calls #as_json on it if
          # it's not from one of these base types.
          # 
          # This allows developers to implement #as_json withouth having to worry
          # about what base types of objects they are allowed to return and having
          # to remember calling #as_json recursively.
          # 
          # By default, the options hash is not passed to the children data structures
          # to avoid undesiarable result. Develoers must opt-in by implementing
          # custom #as_json methods (e.g. Hash#as_json and Array#as_json).
          def jsonify(value)
            if value.is_a?(Hash)
              Hash[value.map { |k, v| [jsonify(k), jsonify(v)] }]
            elsif value.is_a?(Array)
              value.map { |v| jsonify(v) }
            elsif value.is_a?(String)
              EscapedString.new(value)
            elsif value.is_a?(Numeric)
              value
            elsif value == true
              true
            elsif value == false
              false
            elsif value == nil
              nil
            else
              jsonify value.as_json
            end
          end

          # Encode a "jsonified" Ruby data structure using the JSON gem
          def stringify(jsonified)
            ::JSON.generate(jsonified, quirks_mode: true, max_nesting: false)
          end
      end

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back
        # to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        # If true, encode >, <, & as escaped unicode sequences (e.g. > as \u003e)
        # as a safety measure.
        attr_accessor :escape_html_entities_in_json

        # Sets the encoder used by Rails to encode Ruby objects into JSON strings
        # in +Object#to_json+ and +ActiveSupport::JSON.encode+.
        attr_accessor :json_encoder

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
      self.json_encoder = JSONGemEncoder
    end
  end
end

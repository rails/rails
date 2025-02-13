# frozen_string_literal: true

require "active_support/core_ext/object/json"
require "active_support/core_ext/module/delegation"

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :time_precision, :time_precision=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :json_encoder, :json_encoder=,
      to: :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # Dumps objects in JSON (JavaScript Object Notation).
    # See http://www.json.org for more info.
    #
    #   ActiveSupport::JSON.encode({ team: 'rails', players: '36' })
    #   # => "{\"team\":\"rails\",\"players\":\"36\"}"
    class << self
      def encode(value, options = nil)
        if options.nil?
          Encoding.encode_without_options(value)
        else
          Encoding.json_encoder.new(options).encode(value)
        end
      end
      alias_method :dump, :encode
    end

    module Encoding # :nodoc:
      U2028 = -"\u2028".b
      U2029 = -"\u2029".b

      ESCAPED_CHARS = {
        U2028 => '\u2028'.b,
        U2029 => '\u2029'.b,
        ">".b => '\u003e'.b,
        "<".b => '\u003c'.b,
        "&".b => '\u0026'.b,
      }

      ESCAPE_REGEX_WITH_HTML_ENTITIES = Regexp.union(*ESCAPED_CHARS.keys)
      ESCAPE_REGEX_WITHOUT_HTML_ENTITIES = Regexp.union(U2028, U2029)

      class JSONGemEncoder # :nodoc:
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        # Encode the given object into a JSON string
        def encode(value)
          unless options.empty?
            value = value.as_json(options.dup.freeze)
          end
          json = stringify(jsonify(value))

          # Rails does more escaping than the JSON gem natively does (we
          # escape \u2028 and \u2029 and optionally >, <, & to work around
          # certain browser problems).
          json.force_encoding(::Encoding::BINARY)
          if @options.fetch(:escape_html_entities, Encoding.escape_html_entities_in_json)
            json.gsub!(ESCAPE_REGEX_WITH_HTML_ENTITIES, ESCAPED_CHARS)
          else
            json.gsub!(ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, ESCAPED_CHARS)
          end
          json.force_encoding(::Encoding::UTF_8)
        end

        private
          # Convert an object into a "JSON-ready" representation composed of
          # primitives like Hash, Array, String, Symbol, Numeric,
          # and +true+/+false+/+nil+.
          # Recursively calls #as_json to the object to recursively build a
          # fully JSON-ready object.
          #
          # This allows developers to implement #as_json without having to
          # worry about what base types of objects they are allowed to return
          # or having to remember to call #as_json recursively.
          #
          # Note: the +options+ hash passed to +object.to_json+ is only passed
          # to +object.as_json+, not any of this method's recursive +#as_json+
          # calls.
          def jsonify(value)
            case value
            when String, Integer, Symbol, nil, true, false
              value
            when Numeric
              value.as_json
            when Hash
              result = {}
              value.each do |k, v|
                k = k.to_s unless Symbol === k || String === k
                result[k] = jsonify(v)
              end
              result
            when Array
              value.map { |v| jsonify(v) }
            else
              if defined?(::JSON::Fragment) && ::JSON::Fragment === value
                value
              else
                jsonify value.as_json
              end
            end
          end

          # Encode a "jsonified" Ruby data structure using the JSON gem
          def stringify(jsonified)
            ::JSON.generate(jsonified)
          end
      end

      if defined?(::JSON::Coder)
        class JSONGemCoderEncoder # :nodoc:
          JSON_NATIVE_TYPES = [Hash, Array, Float, String, Symbol, Integer, NilClass, TrueClass, FalseClass, ::JSON::Fragment].freeze
          CODER = ::JSON::Coder.new do |value|
            json_value = value.as_json
            # Handle objects returning self from as_json
            if json_value.equal?(value)
              next ::JSON::Fragment.new(::JSON.generate(json_value))
            end
            # Handle objects not returning JSON-native types from as_json
            count = 5
            until JSON_NATIVE_TYPES.include?(json_value.class)
              raise SystemStackError if count == 0
              json_value = json_value.as_json
              count -= 1
            end
            json_value
          end


          def initialize(options = nil)
            @options = options ? options.dup.freeze : {}.freeze
          end

          # Encode the given object into a JSON string
          def encode(value)
            value = value.as_json(@options) unless @options.empty?

            json = CODER.dump(value)

            # Rails does more escaping than the JSON gem natively does (we
            # escape \u2028 and \u2029 and optionally >, <, & to work around
            # certain browser problems).
            json.force_encoding(::Encoding::BINARY)
            if @options.fetch(:escape_html_entities, Encoding.escape_html_entities_in_json)
              json.gsub!(ESCAPE_REGEX_WITH_HTML_ENTITIES, ESCAPED_CHARS)
            else
              json.gsub!(ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, ESCAPED_CHARS)
            end
            json.force_encoding(::Encoding::UTF_8)
          end
        end
      end

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back
        # to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        # If true, encode >, <, & as escaped unicode sequences (e.g. > as \u003e)
        # as a safety measure.
        attr_accessor :escape_html_entities_in_json

        # Sets the precision of encoded time values.
        # Defaults to 3 (equivalent to millisecond precision)
        attr_accessor :time_precision

        # Sets the encoder used by \Rails to encode Ruby objects into JSON strings
        # in +Object#to_json+ and +ActiveSupport::JSON.encode+.
        attr_reader :json_encoder

        def json_encoder=(encoder)
          @json_encoder = encoder
          @encoder_without_options = encoder.new
        end

        def encode_without_options(value) # :nodoc:
          @encoder_without_options.encode(value)
        end
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = true
      self.json_encoder =
        if defined?(::JSON::Coder)
          JSONGemCoderEncoder
        else
          JSONGemEncoder
        end
      self.time_precision = 3
    end
  end
end

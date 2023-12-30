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
        Encoding.json_encoder.new(options).encode(value)
      end
      alias_method :dump, :encode
    end

    module Encoding # :nodoc:
      class JSONGemEncoder # :nodoc:
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        # Encode the given object into a JSON string
        def encode(value)
          unless options.empty?
            value = value.as_json(options.dup)
          end
          json = stringify(jsonify(value))

          # Rails does more escaping than the JSON gem natively does (we
          # escape \u2028 and \u2029 and optionally >, <, & to work around
          # certain browser problems).
          if Encoding.escape_html_entities_in_json
            json.gsub!(">", '\u003e')
            json.gsub!("<", '\u003c')
            json.gsub!("&", '\u0026')
          end
          json.gsub!("\u2028", '\u2028')
          json.gsub!("\u2029", '\u2029')
          json
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
                k = k.to_s unless String === k
                result[k] = jsonify(v)
              end
              result
            when Array
              value.map { |v| jsonify(v) }
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

        # Sets the precision of encoded time values.
        # Defaults to 3 (equivalent to millisecond precision)
        attr_accessor :time_precision

        # Sets the encoder used by \Rails to encode Ruby objects into JSON strings
        # in +Object#to_json+ and +ActiveSupport::JSON.encode+.
        attr_accessor :json_encoder
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = true
      self.json_encoder = JSONGemEncoder
      self.time_precision = 3
    end
  end
end

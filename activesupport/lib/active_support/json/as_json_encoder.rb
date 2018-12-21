module ActiveSupport
  module JSON
    class AsJSONEncoder
      def self.encode(object, options)
        new(options).encode object
      end

      def self.encode_next(object, options)
        new(options).visit object
      end

      def self.internal_as_json?(object)
        !object.respond_to?(:as_json) ||
          object.method(:as_json).owner == ActiveSupport::AsJSON
      end

      def initialize(as_json_options)
        @as_json_options = as_json_options
      end

      def encode(object)
        if AsJSONEncoder.internal_as_json?(object)
          visit object
        else
          # **ONLY** top level objects implementing as_json should
          # get the options hash
          if !@as_json_options.nil?
            self.class.new(nil).encode object.as_json(@as_json_options.dup)
          else
            self.class.new(nil).encode object.as_json
          end
        end
      end

      def visit(object)
        case object
        when Hash            then handle_Hash           object
        when Array           then handle_Array          object
        when Float           then handle_Float          object
        when BigDecimal      then handle_Float          object
        when Struct          then handle_Struct         object
        when FalseClass      then identity              object
        when TrueClass       then identity              object
        when NilClass        then identity              object
        when String          then handle_String         object
        when Numeric         then identity              object
        when Symbol          then to_string             object
        when Regexp          then to_string             object
        when IO              then to_string             object
        when Range           then to_string             object
        when Exception       then to_string             object
        when Pathname        then to_string             object
        when URI::Generic    then to_string             object
        when DateTime        then handle_DateTime       object
        when Time            then handle_Time           object
        when Date            then handle_Date           object
        when Process::Status then handle_Process_Status object
        when Enumerable      then handle_Enumerable     object
        else
          handle_default object
        end
      end

      private

        def handle_String(object)
          object
        end

        def handle_default(object)
          if object.respond_to?(:to_hash)
            encode object.to_hash
          else
            encode object.instance_values
          end
        end

        # A BigDecimal would be naturally represented as a JSON number. Most libraries,
        # however, parse non-integer JSON numbers directly as floats. Clients using
        # those libraries would get in general a wrong number and no way to recover
        # other than manually inspecting the string with the JSON code itself.
        #
        # That's why a JSON string is returned. The JSON literal is not numeric, but
        # if the other end knows by contract that the data is supposed to be a
        # BigDecimal, it still has the chance to post-process the string and get the
        # real value.

        # Encoding Infinity or NaN to JSON should return "null". The default returns
        # "Infinity" or "NaN" which are not valid JSON.
        def handle_Float(object)
          object.finite? ? object : nil
        end

        def handle_Process_Status(object)
          encode({ exitstatus: object.exitstatus, pid: object.pid })
        end

        def handle_Struct(object)
          encode Hash[object.members.zip(object.values)]
        end

        def handle_Date(object)
          if ActiveSupport::JSON::Encoding.use_standard_json_time_format
            object.strftime("%Y-%m-%d")
          else
            object.strftime("%Y/%m/%d")
          end
        end

        def handle_DateTime(object)
          if ActiveSupport::JSON::Encoding.use_standard_json_time_format
            object.xmlschema(ActiveSupport::JSON::Encoding.time_precision)
          else
            object.strftime("%Y/%m/%d %H:%M:%S %z")
          end
        end

        def handle_Time(object)
          if ActiveSupport::JSON::Encoding.use_standard_json_time_format
            object.xmlschema(ActiveSupport::JSON::Encoding.time_precision)
          else
            %(#{object.strftime("%Y/%m/%d %H:%M:%S")} #{object.formatted_offset(false)})
          end
        end

        def identity(object)
          object
        end

        def to_string(object)
          object.to_s
        end

        def handle_Enumerable(object)
          encode object.to_a
        end

        def handle_Array(object)
          object.map { |v| encode v }
        end

        def handle_Hash(object)
          options = @as_json_options
          # create a subset of the hash by applying :only or :except
          subset = if options
            if attrs = options[:only]
              object.slice(*Array(attrs))
            elsif attrs = options[:except]
              object.except(*Array(attrs))
            else
              object
            end
          else
            object
          end

          Hash[subset.map { |k, v| [encode(k), encode(v)] } ]
        end
    end

    class EscapedAsJSONEncoder < AsJSONEncoder
      # Rails does more escaping than the JSON gem natively does (we
      # escape \u2028 and \u2029 and optionally >, <, & to work around
      # certain browser problems).
      ESCAPED_CHARS = {
        "\u2028" => '\u2028',
        "\u2029" => '\u2029',
        ">"      => '\u003e',
        "<"      => '\u003c',
        "&"      => '\u0026',
      }

      ESCAPE_REGEX_WITH_HTML_ENTITIES = /[\u2028\u2029><&]/u
      ESCAPE_REGEX_WITHOUT_HTML_ENTITIES = /[\u2028\u2029]/u

      # This class wraps all the strings we see and does the extra escaping
      class EscapedString < String #:nodoc:
        def to_json(*)
          if Encoding.escape_html_entities_in_json
            s = super
            s.gsub! ESCAPE_REGEX_WITH_HTML_ENTITIES, ESCAPED_CHARS
            s
          else
            s = super
            s.gsub! ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, ESCAPED_CHARS
            s
          end
        end

        def to_s
          self
        end
      end

      # Mark these as private so we don't leak encoding-specific constructs
      private_constant :ESCAPED_CHARS, :ESCAPE_REGEX_WITH_HTML_ENTITIES,
        :ESCAPE_REGEX_WITHOUT_HTML_ENTITIES, :EscapedString


      private

        def handle_String(object)
          EscapedString.new(object)
        end
    end
  end
end

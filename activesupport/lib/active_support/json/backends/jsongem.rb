require 'json' unless defined?(JSON)

module ActiveSupport
  module JSON
    ParseError = ::JSON::ParserError unless const_defined?(:ParseError)

    module Backends
      module JSONGem
        extend self

        # Parses a JSON string or IO and convert it into an object
        def decode(json)
          if json.respond_to?(:read)
            json = json.read
          end
          data = ::JSON.parse(json)
          if ActiveSupport.parse_json_times
            convert_dates_from(data)
          else
            data
          end
        end

      private
        def convert_dates_from(data)
          case data
            when DATE_REGEX
              DateTime.parse(data)
            when Array
              data.map! { |d| convert_dates_from(d) }
            when Hash
              data.each do |key, value|
                data[key] = convert_dates_from(value)
              end
            else data
          end
        end
      end
    end
  end
end
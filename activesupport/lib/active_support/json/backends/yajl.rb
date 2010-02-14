require 'yajl-ruby' unless defined?(Yajl)

module ActiveSupport
  module JSON
    module Backends
      module Yajl
        ParseError = ::Yajl::ParseError
        extend self

        # Parses a JSON string or IO and convert it into an object
        def decode(json)
          data = ::Yajl::Parser.new.parse(json)
          if ActiveSupport.parse_json_times
            convert_dates_from(data)
          else
            data
          end
        end

      private
        def convert_dates_from(data)
          case data
          when nil
            nil
          when DATE_REGEX
            DateTime.parse(data)
          when Array
            data.map! { |d| convert_dates_from(d) }
          when Hash
            data.each do |key, value|
              data[key] = convert_dates_from(value)
            end
          else
            data
          end
        end
      end
    end
  end
end

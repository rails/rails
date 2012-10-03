require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'multi_json'

module ActiveSupport
  # Look for and parse json strings that look like ISO 8601 times.
  mattr_accessor :parse_json_times

  module JSON
    class << self
      # Parses a JSON string (JavaScript Object Notation) into a hash.
      # See www.json.org for more info.
      #
      #   ActiveSupport::JSON.decode("{\"team\":\"rails\",\"players\":\"36\"}")
      #   => {"team" => "rails", "players" => "36"}
      def decode(json, options ={})
        data = MultiJson.load(json, options)
        if ActiveSupport.parse_json_times
          convert_dates_from(data)
        else
          data
        end
      end

      def engine
        MultiJson.adapter
      end
      alias :backend :engine

      def engine=(name)
        MultiJson.use(name)
      end
      alias :backend= :engine=

      def with_backend(name)
        old_backend, self.backend = backend, name
        yield
      ensure
        self.backend = old_backend
      end

      # Returns the class of the error that will be raised when there is an
      # error in decoding JSON. Using this method means you won't directly
      # depend on the ActiveSupport's JSON implementation, in case it changes
      # in the future.
      #
      #   begin
      #     obj = ActiveSupport::JSON.decode(some_string)
      #   rescue ActiveSupport::JSON.parse_error
      #     Rails.logger.warn("Attempted to decode invalid JSON: #{some_string}")
      #   end
      def parse_error
        MultiJson::DecodeError
      end

      private

      def convert_dates_from(data)
        case data
        when nil
          nil
        when DATE_REGEX
          begin
            DateTime.parse(data)
          rescue ArgumentError
            data
          end
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

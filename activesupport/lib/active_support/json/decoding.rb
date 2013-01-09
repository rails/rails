require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'multi_json'

module ActiveSupport
  # Look for and parse json strings that look like ISO 8601 times.
  mattr_accessor :parse_json_times

  module JSON
    class << self
      def decode(json, options ={})
        # Can't reliably detect whether MultiJson responds to load, since it's
        # a reserved word. Use adapter as a proxy for new features.
        data = if MultiJson.respond_to?(:adapter)
          MultiJson.load(json, options)
        else
          MultiJson.decode(json, options)
        end
        if ActiveSupport.parse_json_times
          convert_dates_from(data)
        else
          data
        end
      end

      def engine
        if MultiJson.respond_to?(:adapter)
          MultiJson.adapter
        else
          MultiJson.engine
        end
      end
      alias :backend :engine

      def engine=(name)
        if MultiJson.respond_to?(:use)
          MultiJson.use name
        else
          MultiJson.engine = name
        end
      end
      alias :backend= :engine=

      def with_backend(name)
        old_backend, self.backend = backend, name
        yield
      ensure
        self.backend = old_backend
      end

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

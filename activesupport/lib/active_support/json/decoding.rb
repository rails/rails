require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # Look for and parse json strings that look like ISO 8601 times.
  mattr_accessor :parse_json_times

  module JSON
    # Listed in order of preference.
    DECODERS = %w(Yajl OkJson)

    class << self
      attr_reader :parse_error
      delegate :decode, :to => :backend

      def backend
        set_default_backend unless defined?(@backend)
        @backend
      end

      def backend=(name)
        if name.is_a?(Module)
          @backend = name
        else
          require "active_support/json/backends/#{name.to_s.downcase}"
          @backend = ActiveSupport::JSON::Backends::const_get(name)
        end
        @parse_error = @backend::ParseError
      end

      def with_backend(name)
        old_backend, self.backend = backend, name
        yield
      ensure
        self.backend = old_backend
      end

      def set_default_backend
        DECODERS.find do |name|
          begin
            self.backend = name
            true
          rescue LoadError
            # Try next decoder.
            false
          end
        end
      end
    end
  end
end

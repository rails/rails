require 'uri'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method

      def initialize(config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end

      def initialize_dup(original)
        @config = original.config.dup
      end

      ##
      # Builds a ConnectionSpecification from user input
      class Resolver # :nodoc:
        attr_reader :config, :klass, :configurations

        def initialize(config, configurations)
          @config         = config
          @configurations = configurations
        end

        def spec
          case config
          when nil
            raise AdapterNotSpecified unless defined?(Rails.env)
            resolve_string_connection Rails.env
          when Symbol, String
            resolve_string_connection config.to_s
          when Hash
            resolve_hash_connection config
          end
        end

        private
        def resolve_string_connection(spec) # :nodoc:
          hash = configurations.fetch(spec) do |k|
            connection_url_to_hash(k)
          end

          raise(AdapterNotSpecified, "#{spec} database is not configured") unless hash

          resolve_hash_connection hash
        end

        def resolve_hash_connection(spec) # :nodoc:
          spec = spec.symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          begin
            require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          rescue LoadError => e
            raise LoadError, "Please install the #{spec[:adapter]} adapter: `gem install activerecord-#{spec[:adapter]}-adapter` (#{e.message})", e.backtrace
          end

          adapter_method = "#{spec[:adapter]}_connection"

          ConnectionSpecification.new(spec, adapter_method)
        end

        # For DATABASE_URL, accept a limited concept of ints and floats
        SIMPLE_INT = /\A\d+\z/
        SIMPLE_FLOAT = /\A\d+\.\d+\z/

        def connection_url_to_hash(url) # :nodoc:
          config = URI.parse url
          adapter = config.scheme
          adapter = "postgresql" if adapter == "postgres"
          spec = { :adapter  => adapter,
                   :username => config.user,
                   :password => config.password,
                   :port     => config.port,
                   :database => config.path.sub(%r{^/},""),
                   :host     => config.host }

          spec.reject!{ |_,value| value.blank? }

          uri_parser = URI::Parser.new

          spec.map { |key,value| spec[key] = uri_parser.unescape(value) if value.is_a?(String) }

          if config.query
            options = Hash[config.query.split("&").map{ |pair| pair.split("=") }].symbolize_keys

            options.each { |key, value| options[key] = type_cast_value(value) }

            spec.merge!(options)
          end

          spec
        end

        def type_cast_value(value)
          case value
          when SIMPLE_INT
            value.to_i
          when SIMPLE_FLOAT
            value.to_f
          when 'true'
            true
          when 'false'
            false
          else
            value
          end
        end
      end
    end
  end
end

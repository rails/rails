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

      # Expands a connection string into a hash.
      class ConnectionUrlResolver # :nodoc:

        # == Example
        #
        #   url = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
        #   ConnectionUrlResolver.new(url).to_hash
        #   # => {
        #     "adapter"  => "postgresql",
        #     "host"     => "localhost",
        #     "port"     => 9000,
        #     "database" => "foo_test",
        #     "username" => "foo",
        #     "password" => "bar",
        #     "pool"     => "5",
        #     "timeout"  => "3000"
        #   }
        def initialize(url)
          raise "Database URL cannot be empty" if url.blank?
          @uri     = URI.parse(url)
          @adapter = @uri.scheme
          @adapter = "postgresql" if @adapter == "postgres"
          @query   = @uri.query || ''
        end

        # Converts the given URL to a full connection hash.
        def to_hash
          config = raw_config.reject { |_,value| value.blank? }
          config.map { |key,value| config[key] = uri_parser.unescape(value) if value.is_a? String }
          config
        end

        private

        def uri
          @uri
        end

        def uri_parser
          @uri_parser ||= URI::Parser.new
        end

        # Converts the query parameters of the URI into a hash.
        #
        #   "localhost?pool=5&reap_frequency=2"
        #   # => { "pool" => "5", "reap_frequency" => "2" }
        #
        # returns empty hash if no query present.
        #
        #   "localhost"
        #   # => {}
        def query_hash
          Hash[@query.split("&").map { |pair| pair.split("=") }]
        end

        def raw_config
          query_hash.merge({
            "adapter"  => @adapter,
            "username" => uri.user,
            "password" => uri.password,
            "port"     => uri.port,
            "database" => database,
            "host"     => uri.host })
        end

        # Returns name of the database.
        # Sqlite3 expects this to be a full path or `:memory:`.
        def database
          if @adapter == 'sqlite3'
            if '/:memory:' == uri.path
              ':memory:'
            else
              uri.path
            end
          else
            uri.path.sub(%r{^/},"")
          end
        end
      end

      ##
      # Builds a ConnectionSpecification from user input.
      class Resolver # :nodoc:
        attr_reader :configurations

        # Accepts a hash two layers deep, keys on the first layer represent
        # environments such as "production". Keys must be strings.
        def initialize(configurations)
          @configurations = configurations
        end

        # Returns a hash with database connection information.
        #
        # == Examples
        #
        # Full hash Configuration.
        #
        #   configurations = { "production" => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" } }
        #   Resolver.new(configurations).resolve(:production)
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3"}
        #
        # Initialized with URL configuration strings.
        #
        #   configurations = { "production" => "postgresql://localhost/foo" }
        #   Resolver.new(configurations).resolve(:production)
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
        #
        def resolve(config)
          if config
            resolve_connection config
          elsif defined?(Rails.env)
            resolve_env_connection Rails.env.to_sym
          else
            raise AdapterNotSpecified
          end
        end

        # Returns an instance of ConnectionSpecification for a given adapter.
        # Accepts a hash one layer deep that contains all connection information.
        #
        # == Example
        #
        #   config = { "production" => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" } }
        #   spec = Resolver.new(config).spec(:production)
        #   spec.adapter_method
        #   # => "sqlite3"
        #   spec.config
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" }
        #
        def spec(config)
          spec = resolve(config).symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          path_to_adapter = "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          begin
            require path_to_adapter
          rescue Gem::LoadError => e
            raise Gem::LoadError, "Specified '#{spec[:adapter]}' for database adapter, but the gem is not loaded. Add `gem '#{e.name}'` to your Gemfile (and ensure its version is at the minimum required by ActiveRecord)."
          rescue LoadError => e
            raise LoadError, "Could not load '#{path_to_adapter}'. Make sure that the adapter in config/database.yml is valid. If you use an adapter other than 'mysql', 'mysql2', 'postgresql' or 'sqlite3' add the necessary adapter gem to the Gemfile.", e.backtrace
          end

          adapter_method = "#{spec[:adapter]}_connection"
          ConnectionSpecification.new(spec, adapter_method)
        end

        private

        # Returns fully resolved connection, accepts hash, string or symbol.
        # Always returns a hash.
        #
        # == Examples
        #
        # Symbol representing current environment.
        #
        #   Resolver.new("production" => {}).resolve_connection(:production)
        #   # => {}
        #
        # One layer deep hash of connection values.
        #
        #   Resolver.new({}).resolve_connection("adapter" => "sqlite3")
        #   # => { "adapter" => "sqlite3" }
        #
        # Connection URL.
        #
        #   Resolver.new({}).resolve_connection("postgresql://localhost/foo")
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
        #
        def resolve_connection(spec)
          case spec
          when Symbol, String
            resolve_env_connection spec
          when Hash
            resolve_hash_connection spec
          end
        end

        # Takes the environment such as `:production` or `:development`.
        # This requires that the @configurations was initialized with a key that
        # matches.
        #
        #
        #   Resolver.new("production" => {}).resolve_env_connection(:production)
        #   # => {}
        #
        # Takes a connection URL.
        #
        #   Resolver.new({}).resolve_env_connection("postgresql://localhost/foo")
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
        #
        def resolve_env_connection(spec)
          # Rails has historically accepted a string to mean either
          # an environment key or a URL spec, so we have deprecated
          # this ambiguous behaviour and in the future this function
          # can be removed in favor of resolve_string_connection and
          # resolve_symbol_connection.
          if config = configurations[spec.to_s]
            if spec.is_a?(String)
              ActiveSupport::Deprecation.warn "Passing a string to ActiveRecord::Base.establish_connection " \
                "for a configuration lookup is deprecated, please pass a symbol (#{spec.to_sym.inspect}) instead"
            end
            resolve_connection(config)
          elsif spec.is_a?(String)
            resolve_string_connection(spec)
          else
            raise(AdapterNotSpecified, "#{spec} database is not configured")
          end
        end

        # Accepts a hash. Expands the "url" key that contains a
        # URL database connection to a full connection
        # hash and merges with the rest of the hash.
        # Connection details inside of the "url" key win any merge conflicts
        def resolve_hash_connection(spec)
          if url = spec.delete("url")
            connection_hash = resolve_string_connection(url)
            spec.merge!(connection_hash)
          end
          spec
        end

        def resolve_string_connection(url)
          ConnectionUrlResolver.new(url).to_hash
        end
      end
    end
  end
end

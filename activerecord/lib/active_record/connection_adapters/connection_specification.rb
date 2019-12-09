# frozen_string_literal: true

require "uri"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification #:nodoc:
      attr_reader :name, :config, :adapter_method

      def initialize(name, config, adapter_method)
        @name, @config, @adapter_method = name, config, adapter_method
      end

      def initialize_dup(original)
        @config = original.config.dup
      end

      def to_hash
        @config.merge(name: @name)
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
          @uri     = uri_parser.parse(url)
          @adapter = @uri.scheme && @uri.scheme.tr("-", "_")
          @adapter = "postgresql" if @adapter == "postgres"

          if @uri.opaque
            @uri.opaque, @query = @uri.opaque.split("?", 2)
          else
            @query = @uri.query
          end
        end

        # Converts the given URL to a full connection hash.
        def to_hash
          config = raw_config.reject { |_, value| value.blank? }
          config.map { |key, value| config[key] = uri_parser.unescape(value) if value.is_a? String }
          config
        end

        private
          attr_reader :uri

          def uri_parser
            @uri_parser ||= URI::Parser.new
          end

          # Converts the query parameters of the URI into a hash.
          #
          #   "localhost?pool=5&reaping_frequency=2"
          #   # => { "pool" => "5", "reaping_frequency" => "2" }
          #
          # returns empty hash if no query present.
          #
          #   "localhost"
          #   # => {}
          def query_hash
            Hash[(@query || "").split("&").map { |pair| pair.split("=", 2) }]
          end

          def raw_config
            if uri.opaque
              query_hash.merge(
                "adapter"  => @adapter,
                "database" => uri.opaque)
            else
              query_hash.merge(
                "adapter"  => @adapter,
                "username" => uri.user,
                "password" => uri.password,
                "port"     => uri.port,
                "database" => database_from_path,
                "host"     => uri.hostname)
            end
          end

          # Returns name of the database.
          def database_from_path
            if @adapter == "sqlite3"
              # 'sqlite3:/foo' is absolute, because that makes sense. The
              # corresponding relative version, 'sqlite3:foo', is handled
              # elsewhere, as an "opaque".

              uri.path
            else
              # Only SQLite uses a filename as the "database" name; for
              # anything else, a leading slash would be silly.

              uri.path.sub(%r{^/}, "")
            end
          end
      end

      ##
      # Builds a ConnectionSpecification from user input.
      class Resolver # :nodoc:
        attr_reader :configurations

        # Accepts a list of db config objects.
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
        def resolve(config_or_env, pool_name = nil)
          if config_or_env
            resolve_connection config_or_env, pool_name
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
        #   # => "sqlite3_connection"
        #   spec.config
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" }
        #
        def spec(config)
          pool_name = config if config.is_a?(Symbol)

          spec = resolve(config, pool_name).symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          # Require the adapter itself and give useful feedback about
          #   1. Missing adapter gems and
          #   2. Adapter gems' missing dependencies.
          path_to_adapter = "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          begin
            require path_to_adapter
          rescue LoadError => e
            # We couldn't require the adapter itself. Raise an exception that
            # points out config typos and missing gems.
            if e.path == path_to_adapter
              # We can assume that a non-builtin adapter was specified, so it's
              # either misspelled or missing from Gemfile.
              raise LoadError, "Could not load the '#{spec[:adapter]}' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

            # Bubbled up from the adapter require. Prefix the exception message
            # with some guidance about how to address it and reraise.
            else
              raise LoadError, "Error loading the '#{spec[:adapter]}' Active Record adapter. Missing a gem it depends on? #{e.message}", e.backtrace
            end
          end

          adapter_method = "#{spec[:adapter]}_connection"

          unless ActiveRecord::Base.respond_to?(adapter_method)
            raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter"
          end

          ConnectionSpecification.new(spec.delete(:name) || "primary", spec, adapter_method)
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
          def resolve_connection(config_or_env, pool_name = nil)
            case config_or_env
            when Symbol
              resolve_symbol_connection config_or_env, pool_name
            when String
              resolve_url_connection config_or_env
            when Hash
              resolve_hash_connection config_or_env
            else
              raise TypeError, "Invalid type for configuration. Expected Symbol, String, or Hash. Got #{config_or_env.inspect}"
            end
          end

          # Takes the environment such as +:production+ or +:development+ and a
          # pool name the corresponds to the name given by the connection pool
          # to the connection. That pool name is merged into the hash with the
          # name key.
          #
          # This requires that the @configurations was initialized with a key that
          # matches.
          #
          #   configurations = #<ActiveRecord::DatabaseConfigurations:0x00007fd9fdace3e0
          #     @configurations=[
          #       #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd9fdace250
          #         @env_name="production", @spec_name="primary", @config={"database"=>"my_db"}>
          #       ]>
          #
          #   Resolver.new(configurations).resolve_symbol_connection(:production, "primary")
          #   # => { "database" => "my_db" }
          def resolve_symbol_connection(env_name, pool_name)
            db_config = configurations.find_db_config(env_name)

            if db_config
              resolve_connection(db_config.config).merge("name" => pool_name.to_s)
            else
              raise AdapterNotSpecified, <<~MSG
                The `#{env_name}` database is not configured for the `#{ActiveRecord::ConnectionHandling::DEFAULT_ENV.call}` environment.

                Available databases configurations are:

                #{build_configuration_sentence}
              MSG
            end
          end

          def build_configuration_sentence # :nodoc:
            configs = configurations.configs_for(include_replicas: true)

            configs.group_by(&:env_name).map do |env, config|
              namespaces = config.map(&:spec_name)
              if namespaces.size > 1
                "#{env}: #{namespaces.join(", ")}"
              else
                env
              end
            end.join("\n")
          end

          # Accepts a hash. Expands the "url" key that contains a
          # URL database connection to a full connection
          # hash and merges with the rest of the hash.
          # Connection details inside of the "url" key win any merge conflicts
          def resolve_hash_connection(spec)
            if spec["url"] && spec["url"] !~ /^jdbc:/
              connection_hash = resolve_url_connection(spec.delete("url"))
              spec.merge!(connection_hash)
            end
            spec
          end

          # Takes a connection URL.
          #
          #   Resolver.new({}).resolve_url_connection("postgresql://localhost/foo")
          #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
          #
          def resolve_url_connection(url)
            ConnectionUrlResolver.new(url).to_hash
          end
      end
    end
  end
end

module ActiveRecord
  module ConnectionHandling
    RAILS_ENV   = -> { Rails.env if defined?(Rails) }
    DEFAULT_ENV = -> { RAILS_ENV.call || "default_env" }

    # Establishes the connection to the database. Accepts a hash as input where
    # the <tt>:adapter</tt> key must be specified with the name of a database adapter (in lower-case)
    # example for regular databases (MySQL, Postgresql, etc):
    #
    #   ActiveRecord::Base.establish_connection(
    #     adapter:  "mysql",
    #     host:     "localhost",
    #     username: "myuser",
    #     password: "mypass",
    #     database: "somedatabase"
    #   )
    #
    # Example for SQLite database:
    #
    #   ActiveRecord::Base.establish_connection(
    #     adapter:  "sqlite3",
    #     database: "path/to/dbfile"
    #   )
    #
    # Also accepts keys as strings (for parsing from YAML for example):
    #
    #   ActiveRecord::Base.establish_connection(
    #     "adapter"  => "sqlite3",
    #     "database" => "path/to/dbfile"
    #   )
    #
    # Or a URL:
    #
    #   ActiveRecord::Base.establish_connection(
    #     "postgres://myuser:mypass@localhost/somedatabase"
    #   )
    #
    # In case <tt>ActiveRecord::Base.configurations</tt> is set (Rails
    # automatically loads the contents of config/database.yml into it),
    # a symbol can also be given as argument, representing a key in the
    # configuration hash:
    #
    #   ActiveRecord::Base.establish_connection(:production)
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
    # may be returned on an error.
    def establish_connection(spec = nil)
      spec     ||= DEFAULT_ENV.call.to_sym
      resolver =   ConnectionAdapters::ConnectionSpecification::Resolver.new configurations
      spec     =   resolver.spec(spec)

      unless respond_to?(spec.adapter_method)
        raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
      end

      remove_connection
      connection_handler.establish_connection self, spec
    end

    class MergeAndResolveDefaultUrlConfig # :nodoc:
      def initialize(raw_configurations)
        @raw_config = raw_configurations.dup
      end

      # Returns fully resolved connection hashes.
      # Merges connection information from `ENV['DATABASE_URL']` if available.
      def resolve
        ConnectionAdapters::ConnectionSpecification::Resolver.new(config).resolve_all
      end

      private
        def config
          cfg = Hash.new do |hash, key|
            entry = @raw_config[key]
            env_url = nil
            if key.to_s == DEFAULT_ENV.call.to_s
              env_url = ENV["DATABASE_URL"]
            end
            env_url ||= ENV["DATABASE_URL_#{key.upcase}"]
            entry ||= {} if env_url
            entry.merge!("url" => env_url) { |h, v1, v2| v1 || v2 } if entry.is_a?(Hash)
            hash[key] = entry if entry
          end

          @raw_config.keys.each {|k| cfg[k] }
          cfg[DEFAULT_ENV.call.to_s]

          cfg
        end
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work unrelated
    # to any of the specific Active Records.
    def connection
      retrieve_connection
    end

    def connection_id
      ActiveRecord::RuntimeRegistry.connection_id
    end

    def connection_id=(connection_id)
      ActiveRecord::RuntimeRegistry.connection_id = connection_id
    end

    # Returns the configuration of the associated connection as a hash:
    #
    #  ActiveRecord::Base.connection_config
    #  # => {pool: 5, timeout: 5000, database: "db/development.sqlite3", adapter: "sqlite3"}
    #
    # Please use only for reading.
    def connection_config
      connection_pool.spec.config
    end

    def connection_pool
      connection_handler.retrieve_connection_pool(self) or raise ConnectionNotEstablished
    end

    def retrieve_connection
      connection_handler.retrieve_connection(self)
    end

    # Returns +true+ if Active Record is connected.
    def connected?
      connection_handler.connected?(self)
    end

    def remove_connection(klass = self)
      connection_handler.remove_connection(klass)
    end

    def clear_cache! # :nodoc:
      connection.schema_cache.clear!
    end

    delegate :clear_active_connections!, :clear_reloadable_connections!,
      :clear_all_connections!, :to => :connection_handler
  end
end

# frozen_string_literal: true

module ActiveRecord
  module ConnectionHandling
    RAILS_ENV   = -> { (Rails.env if defined?(Rails.env)) || ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence }
    DEFAULT_ENV = -> { RAILS_ENV.call || "default_env" }

    # Establishes the connection to the database. Accepts a hash as input where
    # the <tt>:adapter</tt> key must be specified with the name of a database adapter (in lower-case)
    # example for regular databases (MySQL, PostgreSQL, etc):
    #
    #   ActiveRecord::Base.establish_connection(
    #     adapter:  "mysql2",
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
    # In case {ActiveRecord::Base.configurations}[rdoc-ref:Core.configurations]
    # is set (Rails automatically loads the contents of config/database.yml into it),
    # a symbol can also be given as argument, representing a key in the
    # configuration hash:
    #
    #   ActiveRecord::Base.establish_connection(:production)
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and +ArgumentError+
    # may be returned on an error.
    def establish_connection(config = nil)
      raise "Anonymous class is not allowed." unless name

      config ||= DEFAULT_ENV.call.to_sym
      spec_name = self == Base ? "primary" : name
      self.connection_specification_name = spec_name

      resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
      spec = resolver.resolve(config).symbolize_keys
      spec[:name] = spec_name

      # use the primary config if a config is not passed in and
      # it's a three tier config
      spec = spec[spec_name.to_sym] if spec[spec_name.to_sym]

      connection_handler.establish_connection(spec)
    end

    class MergeAndResolveDefaultUrlConfig # :nodoc:
      def initialize(raw_configurations)
        @raw_config = raw_configurations.dup
        @env = DEFAULT_ENV.call.to_s
      end

      # Returns fully resolved connection hashes.
      # Merges connection information from `ENV['DATABASE_URL']` if available.
      def resolve
        ConnectionAdapters::ConnectionSpecification::Resolver.new(config).resolve_all
      end

      private
        def config
          @raw_config.dup.tap do |cfg|
            if url = ENV["DATABASE_URL"]
              cfg[@env] ||= {}
              cfg[@env]["url"] ||= url
            end
          end
        end
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work unrelated
    # to any of the specific Active Records.
    def connection
      retrieve_connection
    end

    attr_writer :connection_specification_name

    # Return the specification name from the current class or its parent.
    def connection_specification_name
      if !defined?(@connection_specification_name) || @connection_specification_name.nil?
        return self == Base ? "primary" : superclass.connection_specification_name
      end
      @connection_specification_name
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
      connection_handler.retrieve_connection_pool(connection_specification_name) || raise(ConnectionNotEstablished)
    end

    def retrieve_connection
      connection_handler.retrieve_connection(connection_specification_name)
    end

    # Returns +true+ if Active Record is connected.
    def connected?
      connection_handler.connected?(connection_specification_name)
    end

    def remove_connection(name = nil)
      name ||= @connection_specification_name if defined?(@connection_specification_name)
      # if removing a connection that has a pool, we reset the
      # connection_specification_name so it will use the parent
      # pool.
      if connection_handler.retrieve_connection_pool(name)
        self.connection_specification_name = nil
      end

      connection_handler.remove_connection(name)
    end

    def clear_cache! # :nodoc:
      connection.schema_cache.clear!
    end

    delegate :clear_active_connections!, :clear_reloadable_connections!,
      :clear_all_connections!, :flush_idle_connections!, to: :connection_handler
  end
end

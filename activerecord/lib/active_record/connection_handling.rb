# frozen_string_literal: true

require "active_record/connection_handling/registration"

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
    #
    # Takes a second optional argument for +handler_key+. This identifies
    # which handler should be used for the connection and is useful for
    # applications with multiple databases.
    #
    #   AcitveRecord::Base.establish_connection :production_replica, :readonly
    #
    # The above will establish a connection to the +production_replica+
    # database using the +readonly+ handler. This tells ActiveRecord
    # which handler to use and will swap the connection accordingly.
    def establish_connection(config_or_env = nil, handler_key = nil)
      config_hash = resolve_config_for_connection(config_or_env)
      handler = connection_handlers[handler_key]

      case handler_key
      when :default
        use_default_connection do
          handler.establish_connection(config_hash)
        end
      when :readonly
        use_readonly_connection do
          handler.establish_connection(config_hash)
        end
      else
        connection_handler.establish_connection(config_hash)
      end
    end

    # Uses the default connection handler when called. In a multi-db
    # application, the +default+ handler corresponds to the write
    # connections which connect to the primary databases.
    def use_default_connection(&blk)
      use_connection(:default, &blk)
    end

    # Uses the +readonly+ connection handler when called. In a multi-db
    # application, the +readonly+ connection handler corresponds to the
    # readonly connections which connect to the replica databases.
    def use_readonly_connection(&blk)
      use_connection(:readonly, &blk)
    end

    def resolve_config_for_connection(config_or_env) # :nodoc:
      raise "Anonymous class is not allowed." unless name

      config_or_env ||= DEFAULT_ENV.call.to_sym
      pool_name = self == Base ? "primary" : name
      self.connection_specification_name = pool_name

      resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
      config_hash = resolver.resolve(config_or_env, pool_name).symbolize_keys
      config_hash[:name] = pool_name

      config_hash
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

    private
      def use_connection(key, &blk) # :nodoc:
        handler = connection_handlers[key]
        swap_connection_handler(handler, &blk)
      end

      def swap_connection_handler(handler, &blk) # :nodoc:
        raise ArgumentError, "connection handler cannot be nil" unless handler
        old_handler, ActiveRecord::Base.connection_handler = ActiveRecord::Base.connection_handler, handler
        yield
      ensure
        ActiveRecord::Base.connection_handler = old_handler
      end
  end
end

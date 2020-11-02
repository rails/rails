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
    def establish_connection(config_or_env = nil)
      config_or_env ||= DEFAULT_ENV.call.to_sym
      db_config, owner_name = resolve_config_for_connection(config_or_env)
      connection_handler.establish_connection(db_config, owner_name: owner_name, role: current_role, shard: current_shard)
    end

    # Connects a model to the databases specified. The +database+ keyword
    # takes a hash consisting of a +role+ and a +database_key+.
    #
    # This will create a connection handler for switching between connections,
    # look up the config hash using the +database_key+ and finally
    # establishes a connection to that config.
    #
    #   class AnimalsModel < ApplicationRecord
    #     self.abstract_class = true
    #
    #     connects_to database: { writing: :primary, reading: :primary_replica }
    #   end
    #
    # +connects_to+ also supports horizontal sharding. The horizontal sharding API
    # also supports read replicas. Connect a model to a list of shards like this:
    #
    #   class AnimalsModel < ApplicationRecord
    #     self.abstract_class = true
    #
    #     connects_to shards: {
    #       default: { writing: :primary, reading: :primary_replica },
    #       shard_two: { writing: :primary_shard_two, reading: :primary_shard_replica_two }
    #     }
    #   end
    #
    # Returns an array of database connections.
    def connects_to(database: {}, shards: {})
      raise NotImplementedError, "`connects_to` can only be called on ActiveRecord::Base or abstract classes" unless self == Base || abstract_class?

      if database.present? && shards.present?
        raise ArgumentError, "`connects_to` can only accept a `database` or `shards` argument, but not both arguments."
      end

      connections = []

      database.each do |role, database_key|
        db_config, owner_name = resolve_config_for_connection(database_key)
        handler = lookup_connection_handler(role.to_sym)

        connections << handler.establish_connection(db_config, owner_name: owner_name, role: role)
      end

      shards.each do |shard, database_keys|
        database_keys.each do |role, database_key|
          db_config, owner_name = resolve_config_for_connection(database_key)
          handler = lookup_connection_handler(role.to_sym)

          connections << handler.establish_connection(db_config, owner_name: owner_name, role: role, shard: shard.to_sym)
        end
      end

      connections
    end

    # Connects to a role (ex writing, reading or a custom role) and/or
    # shard for the duration of the block. At the end of the block the
    # connection will be returned to the original role / shard.
    #
    # If only a role is passed, Active Record will look up the connection
    # based on the requested role. If a non-established role is requested
    # an `ActiveRecord::ConnectionNotEstablished` error will be raised:
    #
    #   ActiveRecord::Base.connected_to(role: :writing) do
    #     Dog.create! # creates dog using dog writing connection
    #   end
    #
    #   ActiveRecord::Base.connected_to(role: :reading) do
    #     Dog.create! # throws exception because we're on a replica
    #   end
    #
    # When swapping to a shard, the role must be passed as well. If a non-existent
    # shard is passed, an `ActiveRecord::ConnectionNotEstablished` error will be
    # raised.
    #
    # When a shard and role is passed, Active Record will first lookup the role,
    # and then look up the connection by shard key.
    #
    #   ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one_replica) do
    #     Dog.first # finds first Dog record stored on the shard one replica
    #   end
    #
    # The database kwarg is deprecated and will be removed in 6.2.0 without replacement.
    def connected_to(database: nil, role: nil, shard: nil, prevent_writes: false, &blk)
      if legacy_connection_handling
        if self != Base
          raise NotImplementedError, "`connected_to` can only be called on ActiveRecord::Base with legacy connection handling."
        end
      else
        if self != Base && !abstract_class
          raise NotImplementedError, "calling `connected_to` is only allowed on ActiveRecord::Base or abstract classes."
        end
      end

      if database && (role || shard)
        raise ArgumentError, "`connected_to` cannot accept a `database` argument with any other arguments."
      elsif database
        ActiveSupport::Deprecation.warn("The database key in `connected_to` is deprecated. It will be removed in Rails 6.2.0 without replacement.")

        if database.is_a?(Hash)
          role, database = database.first
          role = role.to_sym
        end

        db_config, owner_name = resolve_config_for_connection(database)
        handler = lookup_connection_handler(role)

        handler.establish_connection(db_config, owner_name: owner_name, role: role)

        with_handler(role, &blk)
      elsif role || shard
        unless role
          raise ArgumentError, "`connected_to` cannot accept a `shard` argument without a `role`."
        end

        with_role_and_shard(role, shard, prevent_writes, &blk)
      else
        raise ArgumentError, "must provide a `shard` and/or `role`."
      end
    end

    # Use a specified connection.
    #
    # This method is useful for ensuring that a specific connection is
    # being used. For example, when booting a console in readonly mode.
    #
    # It is not recommended to use this method in a request since it
    # does not yield to a block like `connected_to`.
    def connecting_to(role: default_role, shard: default_shard, prevent_writes: false)
      if legacy_connection_handling
        raise NotImplementedError, "`connecting_to` is not available with `legacy_connection_handling`."
      end

      prevent_writes = true if role == reading_role

      self.connected_to_stack << { role: role, shard: shard, prevent_writes: prevent_writes, klass: self }
    end

    # Prevent writing to the database regardless of role.
    #
    # In some cases you may want to prevent writes to the database
    # even if you are on a database that can write. `while_preventing_writes`
    # will prevent writes to the database for the duration of the block.
    #
    # This method does not provide the same protection as a readonly
    # user and is meant to be a safeguard against accidental writes.
    #
    # See `READ_QUERY` for the queries that are blocked by this
    # method.
    def while_preventing_writes(enabled = true, &block)
      if legacy_connection_handling
        connection_handler.while_preventing_writes(enabled, &block)
      else
        connected_to(role: current_role, prevent_writes: enabled, &block)
      end
    end

    # Returns true if role is the current connected role.
    #
    #   ActiveRecord::Base.connected_to(role: :writing) do
    #     ActiveRecord::Base.connected_to?(role: :writing) #=> true
    #     ActiveRecord::Base.connected_to?(role: :reading) #=> false
    #   end
    def connected_to?(role:, shard: ActiveRecord::Base.default_shard)
      current_role == role.to_sym && current_shard == shard.to_sym
    end

    def lookup_connection_handler(handler_key) # :nodoc:
      if ActiveRecord::Base.legacy_connection_handling
        handler_key ||= ActiveRecord::Base.writing_role
        connection_handlers[handler_key] ||= ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      else
        ActiveRecord::Base.connection_handler
      end
    end

    # Clears the query cache for all connections associated with the current thread.
    def clear_query_caches_for_current_thread
      if ActiveRecord::Base.legacy_connection_handling
        ActiveRecord::Base.connection_handlers.each_value do |handler|
          clear_on_handler(handler)
        end
      else
        clear_on_handler(ActiveRecord::Base.connection_handler)
      end
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work unrelated
    # to any of the specific Active Records.
    def connection
      retrieve_connection
    end

    attr_writer :connection_specification_name

    # Return the connection specification name from the current class or its parent.
    def connection_specification_name
      if !defined?(@connection_specification_name) || @connection_specification_name.nil?
        return self == Base ? Base.name : superclass.connection_specification_name
      end
      @connection_specification_name
    end

    def primary_class? # :nodoc:
      self == Base || defined?(ApplicationRecord) && self == ApplicationRecord
    end

    # Returns the configuration of the associated connection as a hash:
    #
    #  ActiveRecord::Base.connection_config
    #  # => {pool: 5, timeout: 5000, database: "db/development.sqlite3", adapter: "sqlite3"}
    #
    # Please use only for reading.
    def connection_config
      connection_pool.db_config.configuration_hash
    end
    deprecate connection_config: "Use connection_db_config instead"

    # Returns the db_config object from the associated connection:
    #
    #  ActiveRecord::Base.connection_db_config
    #    #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbded10 @env_name="development",
    #      @name="primary", @config={pool: 5, timeout: 5000, database: "db/development.sqlite3", adapter: "sqlite3"}>
    #
    # Use only for reading.
    def connection_db_config
      connection_pool.db_config
    end

    def connection_pool
      connection_handler.retrieve_connection_pool(connection_specification_name, role: current_role, shard: current_shard) || raise(ConnectionNotEstablished)
    end

    def retrieve_connection
      connection_handler.retrieve_connection(connection_specification_name, role: current_role, shard: current_shard)
    end

    # Returns +true+ if Active Record is connected.
    def connected?
      connection_handler.connected?(connection_specification_name, role: current_role, shard: current_shard)
    end

    def remove_connection(name = nil)
      name ||= @connection_specification_name if defined?(@connection_specification_name)
      # if removing a connection that has a pool, we reset the
      # connection_specification_name so it will use the parent
      # pool.
      if connection_handler.retrieve_connection_pool(name, role: current_role, shard: current_shard)
        self.connection_specification_name = nil
      end

      connection_handler.remove_connection_pool(name, role: current_role, shard: current_shard)
    end

    def clear_cache! # :nodoc:
      connection.schema_cache.clear!
    end

    delegate :clear_active_connections!, :clear_reloadable_connections!,
      :clear_all_connections!, :flush_idle_connections!, to: :connection_handler

    private
      def clear_on_handler(handler)
        handler.all_connection_pools.each do |pool|
          pool.connection.clear_query_cache if pool.active_connection?
        end
      end

      def resolve_config_for_connection(config_or_env)
        raise "Anonymous class is not allowed." unless name

        owner_name = primary_class? ? Base.name : name
        self.connection_specification_name = owner_name

        db_config = Base.configurations.resolve(config_or_env)
        [db_config, owner_name]
      end

      def with_handler(handler_key, &blk)
        handler = lookup_connection_handler(handler_key)
        swap_connection_handler(handler, &blk)
      end

      def with_role_and_shard(role, shard, prevent_writes)
        prevent_writes = true if role == reading_role

        if ActiveRecord::Base.legacy_connection_handling
          with_handler(role.to_sym) do
            connection_handler.while_preventing_writes(prevent_writes) do
              self.connected_to_stack << { shard: shard, klass: self }
              yield
            end
          end
        else
          self.connected_to_stack << { role: role, shard: shard, prevent_writes: prevent_writes, klass: self }
          return_value = yield
          return_value.load if return_value.is_a? ActiveRecord::Relation
          return_value
        end
      ensure
        self.connected_to_stack.pop
      end

      def swap_connection_handler(handler, &blk) # :nodoc:
        old_handler, ActiveRecord::Base.connection_handler = ActiveRecord::Base.connection_handler, handler
        return_value = yield
        return_value.load if return_value.is_a? ActiveRecord::Relation
        return_value
      ensure
        ActiveRecord::Base.connection_handler = old_handler
      end
  end
end

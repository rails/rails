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
    # The exceptions AdapterNotSpecified, AdapterNotFound, and +ArgumentError+
    # may be returned on an error.
    def establish_connection(config_or_env = nil)
      config_or_env ||= DEFAULT_ENV.call.to_sym
      db_config, connection_class = resolve_config_for_connection(config_or_env)
      connection_handler.establish_connection(db_config, owner_name: connection_class, role: current_role, shard: current_shard)
    end

    # Connects a model to the databases specified. The +database+ keyword
    # takes a hash consisting of a +role+ and a +database_key+.
    #
    # This will look up the database config using the +database_key+ and
    # establish a connection to that config.
    #
    #   class AnimalsModel < ApplicationRecord
    #     self.abstract_class = true
    #
    #     connects_to database: { writing: :primary, reading: :primary_replica }
    #   end
    #
    # +connects_to+ also supports horizontal sharding. The horizontal sharding API
    # supports read replicas as well. You can connect a model to a list of shards like this:
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
        db_config, connection_class = resolve_config_for_connection(database_key)

        self.connection_class = true
        connections << connection_handler.establish_connection(db_config, owner_name: connection_class, role: role)
      end

      shards.each do |shard, database_keys|
        database_keys.each do |role, database_key|
          db_config, connection_class = resolve_config_for_connection(database_key)

          self.connection_class = true
          connections << connection_handler.establish_connection(db_config, owner_name: connection_class, role: role, shard: shard.to_sym)
        end
      end

      connections
    end

    # Connects to a role (e.g. writing, reading, or a custom role) and/or
    # shard for the duration of the block. At the end of the block the
    # connection will be returned to the original role / shard.
    #
    # If only a role is passed, Active Record will look up the connection
    # based on the requested role. If a non-established role is requested
    # an +ActiveRecord::ConnectionNotEstablished+ error will be raised:
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
    # shard is passed, an +ActiveRecord::ConnectionNotEstablished+ error will be
    # raised.
    #
    # When a shard and role is passed, Active Record will first lookup the role,
    # and then look up the connection by shard key.
    #
    #   ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one_replica) do
    #     Dog.first # finds first Dog record stored on the shard one replica
    #   end
    def connected_to(role: nil, shard: nil, prevent_writes: false, &blk)
      if self != Base && !abstract_class
        raise NotImplementedError, "calling `connected_to` is only allowed on ActiveRecord::Base or abstract classes."
      end

      if !connection_class? && !primary_class?
        raise NotImplementedError, "calling `connected_to` is only allowed on the abstract class that established the connection."
      end

      unless role || shard
        raise ArgumentError, "must provide a `shard` and/or `role`."
      end

      with_role_and_shard(role, shard, prevent_writes, &blk)
    end

    # Connects a role and/or shard to the provided connection names. Optionally +prevent_writes+
    # can be passed to block writes on a connection. +reading+ will automatically set
    # +prevent_writes+ to true.
    #
    # +connected_to_many+ is an alternative to deeply nested +connected_to+ blocks.
    #
    # Usage:
    #
    #   ActiveRecord::Base.connected_to_many(AnimalsRecord, MealsRecord, role: :reading) do
    #     Dog.first # Read from animals replica
    #     Dinner.first # Read from meals replica
    #     Person.first # Read from primary writer
    #   end
    def connected_to_many(*classes, role:, shard: nil, prevent_writes: false)
      classes = classes.flatten

      if self != Base || classes.include?(Base)
        raise NotImplementedError, "connected_to_many can only be called on ActiveRecord::Base."
      end

      prevent_writes = true if role == ActiveRecord.reading_role

      append_to_connected_to_stack(role: role, shard: shard, prevent_writes: prevent_writes, klasses: classes)
      yield
    ensure
      connected_to_stack.pop
    end

    # Use a specified connection.
    #
    # This method is useful for ensuring that a specific connection is
    # being used. For example, when booting a console in readonly mode.
    #
    # It is not recommended to use this method in a request since it
    # does not yield to a block like +connected_to+.
    def connecting_to(role: default_role, shard: default_shard, prevent_writes: false)
      prevent_writes = true if role == ActiveRecord.reading_role

      append_to_connected_to_stack(role: role, shard: shard, prevent_writes: prevent_writes, klasses: [self])
    end

    # Prohibit swapping shards while inside of the passed block.
    #
    # In some cases you may want to be able to swap shards but not allow a
    # nested call to connected_to or connected_to_many to swap again. This
    # is useful in cases you're using sharding to provide per-request
    # database isolation.
    def prohibit_shard_swapping(enabled = true)
      prev_value = ActiveSupport::IsolatedExecutionState[:active_record_prohibit_shard_swapping]
      ActiveSupport::IsolatedExecutionState[:active_record_prohibit_shard_swapping] = enabled
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[:active_record_prohibit_shard_swapping] = prev_value
    end

    # Determine whether or not shard swapping is currently prohibited
    def shard_swapping_prohibited?
      ActiveSupport::IsolatedExecutionState[:active_record_prohibit_shard_swapping]
    end

    # Prevent writing to the database regardless of role.
    #
    # In some cases you may want to prevent writes to the database
    # even if you are on a database that can write. +while_preventing_writes+
    # will prevent writes to the database for the duration of the block.
    #
    # This method does not provide the same protection as a readonly
    # user and is meant to be a safeguard against accidental writes.
    #
    # See +READ_QUERY+ for the queries that are blocked by this
    # method.
    def while_preventing_writes(enabled = true, &block)
      connected_to(role: current_role, prevent_writes: enabled, &block)
    end

    # Returns true if role and/or is the current connected role and/or
    # current connected shard. If no shard is passed the default will be
    # used.
    #
    #   ActiveRecord::Base.connected_to(role: :writing) do
    #     ActiveRecord::Base.connected_to?(role: :writing) #=> true
    #     ActiveRecord::Base.connected_to?(role: :reading) #=> false
    #   end
    #
    #   ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one) do
    #     ActiveRecord::Base.connected_to?(role: :reading, shard: :shard_one) #=> true
    #     ActiveRecord::Base.connected_to?(role: :reading, shard: :default) #=> false
    #     ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one) #=> true
    #   end
    def connected_to?(role:, shard: ActiveRecord::Base.default_shard)
      current_role == role.to_sym && current_shard == shard.to_sym
    end

    # Clears the query cache for all connections associated with the current thread.
    def clear_query_caches_for_current_thread
      connection_handler.each_connection_pool do |pool|
        pool.connection.clear_query_cache if pool.active_connection?
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
      self == Base || application_record_class?
    end

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
      def resolve_config_for_connection(config_or_env)
        raise "Anonymous class is not allowed." unless name

        connection_name = primary_class? ? Base.name : name
        self.connection_specification_name = connection_name

        db_config = Base.configurations.resolve(config_or_env)
        [db_config, self]
      end

      def with_role_and_shard(role, shard, prevent_writes)
        prevent_writes = true if role == ActiveRecord.reading_role

        append_to_connected_to_stack(role: role, shard: shard, prevent_writes: prevent_writes, klasses: [self])
        return_value = yield
        return_value.load if return_value.is_a? ActiveRecord::Relation
        return_value
      ensure
        self.connected_to_stack.pop
      end

      def append_to_connected_to_stack(entry)
        if shard_swapping_prohibited? && entry[:shard].present?
          raise ArgumentError, "cannot swap `shard` while shard swapping is prohibited."
        end

        connected_to_stack << entry
      end
  end
end

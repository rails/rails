# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module ConnectionAdapters
    # = Active Record Connection Handler
    #
    # ConnectionHandler is a collection of ConnectionPool objects. It is used
    # for keeping separate connection pools that connect to different databases.
    #
    # For example, suppose that you have 5 models, with the following hierarchy:
    #
    #   class Author < ActiveRecord::Base
    #   end
    #
    #   class BankAccount < ActiveRecord::Base
    #   end
    #
    #   class Book < ActiveRecord::Base
    #     establish_connection :library_db
    #   end
    #
    #   class ScaryBook < Book
    #   end
    #
    #   class GoodBook < Book
    #   end
    #
    # And a database.yml that looked like this:
    #
    #   development:
    #     database: my_application
    #     host: localhost
    #
    #   library_db:
    #     database: library
    #     host: some.library.org
    #
    # Your primary database in the development environment is "my_application"
    # but the Book model connects to a separate database called "library_db"
    # (this can even be a database on a different machine).
    #
    # Book, ScaryBook, and GoodBook will all use the same connection pool to
    # "library_db" while Author, BankAccount, and any other models you create
    # will use the default connection pool to "my_application".
    #
    # The various connection pools are managed by a single instance of
    # ConnectionHandler accessible via ActiveRecord::Base.connection_handler.
    # All Active Record models use this handler to determine the connection pool that they
    # should use.
    #
    # The ConnectionHandler class is not coupled with the Active models, as it has no knowledge
    # about the model. The model needs to pass a connection specification name to the handler,
    # in order to look up the correct connection pool.
    class ConnectionHandler
      class StringConnectionName # :nodoc:
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def primary_class?
          false
        end

        def current_preventing_writes
          false
        end
      end

      def initialize
        # These caches are keyed by pool_config.connection_name (PoolConfig#connection_name).
        @connection_name_to_pool_manager = Concurrent::Map.new(initial_capacity: 2)
      end

      def prevent_writes # :nodoc:
        ActiveSupport::IsolatedExecutionState[:active_record_prevent_writes]
      end

      def prevent_writes=(prevent_writes) # :nodoc:
        ActiveSupport::IsolatedExecutionState[:active_record_prevent_writes] = prevent_writes
      end

      def connection_pool_names # :nodoc:
        connection_name_to_pool_manager.keys
      end

      # Returns the pools for a connection handler and given role. If +:all+ is passed,
      # all pools belonging to the connection handler will be returned.
      def connection_pool_list(role = nil)
        if role.nil? || role == :all
          connection_name_to_pool_manager.values.flat_map { |m| m.pool_configs.map(&:pool) }
        else
          connection_name_to_pool_manager.values.flat_map { |m| m.pool_configs(role).map(&:pool) }
        end
      end
      alias :connection_pools :connection_pool_list

      def each_connection_pool(role = nil, &block) # :nodoc:
        role = nil if role == :all
        return enum_for(__method__, role) unless block_given?

        connection_name_to_pool_manager.each_value do |manager|
          manager.each_pool_config(role) do |pool_config|
            yield pool_config.pool
          end
        end
      end

      def establish_connection(config, owner_name: Base, role: Base.current_role, shard: Base.current_shard, clobber: false)
        owner_name = determine_owner_name(owner_name, config)

        pool_config = resolve_pool_config(config, owner_name, role, shard)
        db_config = pool_config.db_config

        pool_manager = set_pool_manager(pool_config.connection_name)

        # If there is an existing pool with the same values as the pool_config
        # don't remove the connection. Connections should only be removed if we are
        # establishing a connection on a class that is already connected to a different
        # configuration.
        existing_pool_config = pool_manager.get_pool_config(role, shard)

        if !clobber && existing_pool_config && existing_pool_config.db_config == db_config
          # Update the pool_config's connection class if it differs. This is used
          # for ensuring that ActiveRecord::Base and the primary_abstract_class use
          # the same pool. Without this granular swapping will not work correctly.
          if owner_name.primary_class? && (existing_pool_config.connection_class != owner_name)
            existing_pool_config.connection_class = owner_name
          end

          existing_pool_config.pool
        else
          disconnect_pool_from_pool_manager(pool_manager, role, shard)
          pool_manager.set_pool_config(role, shard, pool_config)

          payload = {
            connection_name: pool_config.connection_name,
            role: role,
            shard: shard,
            config: db_config.configuration_hash
          }

          ActiveSupport::Notifications.instrumenter.instrument("!connection.active_record", payload) do
            pool_config.pool
          end
        end
      end

      # Returns true if there are any active connections among the connection
      # pools that the ConnectionHandler is managing.
      def active_connections?(role = nil)
        each_connection_pool(role).any?(&:active_connection?)
      end

      # Returns any connections in use by the current thread back to the pool,
      # and also returns connections to the pool cached by threads that are no
      # longer alive.
      def clear_active_connections!(role = nil)
        each_connection_pool(role).each do |pool|
          pool.release_connection
          pool.disable_query_cache!
        end
      end

      # Clears the cache which maps classes.
      #
      # See ConnectionPool#clear_reloadable_connections! for details.
      def clear_reloadable_connections!(role = nil)
        each_connection_pool(role).each(&:clear_reloadable_connections!)
      end

      def clear_all_connections!(role = nil)
        each_connection_pool(role).each(&:disconnect!)
      end

      # Disconnects all currently idle connections.
      #
      # See ConnectionPool#flush! for details.
      def flush_idle_connections!(role = nil)
        each_connection_pool(role).each(&:flush!)
      end

      # Locate the connection of the nearest super class. This can be an
      # active or defined connection: if it is the latter, it will be
      # opened and set as the active connection for the class it was defined
      # for (not necessarily the current class).
      def retrieve_connection(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard) # :nodoc:
        pool = retrieve_connection_pool(connection_name, role: role, shard: shard, strict: true)
        pool.lease_connection
      end

      # Returns true if a connection that's accessible to this class has
      # already been opened.
      def connected?(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        pool = retrieve_connection_pool(connection_name, role: role, shard: shard)
        pool && pool.connected?
      end

      def remove_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        if pool_manager = get_pool_manager(connection_name)
          disconnect_pool_from_pool_manager(pool_manager, role, shard)
        end
      end

      # Retrieving the connection pool happens a lot, so we cache it in @connection_name_to_pool_manager.
      # This makes retrieving the connection pool O(1) once the process is warm.
      # When a connection is established or removed, we invalidate the cache.
      def retrieve_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard, strict: false)
        pool_manager = get_pool_manager(connection_name)
        pool = pool_manager&.get_pool_config(role, shard)&.pool

        if strict && !pool
          selector = [
            ("'#{shard}' shard" unless shard == ActiveRecord::Base.default_shard),
            ("'#{role}' role" unless role == ActiveRecord::Base.default_role),
          ].compact.join(" and ")

          selector = [
            (connection_name unless connection_name == "ActiveRecord::Base"),
            selector.presence,
          ].compact.join(" with ")

          selector = " for #{selector}" if selector.present?

          message = "No database connection defined#{selector}."

          raise ConnectionNotDefined.new(message, connection_name: connection_name, shard: shard, role: role)
        end

        pool
      end

      private
        attr_reader :connection_name_to_pool_manager

        # Returns the pool manager for a connection name / identifier.
        def get_pool_manager(connection_name)
          connection_name_to_pool_manager[connection_name]
        end

        # Get the existing pool manager or initialize and assign a new one.
        def set_pool_manager(connection_name)
          connection_name_to_pool_manager[connection_name] ||= PoolManager.new
        end

        def pool_managers
          connection_name_to_pool_manager.values
        end

        def disconnect_pool_from_pool_manager(pool_manager, role, shard)
          pool_config = pool_manager.remove_pool_config(role, shard)

          if pool_config
            pool_config.disconnect!
            pool_config.db_config
          end
        end

        # Returns an instance of PoolConfig for a given adapter.
        # Accepts a hash one layer deep that contains all connection information.
        #
        # == Example
        #
        #   config = { "production" => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" } }
        #   pool_config = Base.configurations.resolve_pool_config(:production)
        #   pool_config.db_config.configuration_hash
        #   # => { host: "localhost", database: "foo", adapter: "sqlite3" }
        #
        def resolve_pool_config(config, connection_name, role, shard)
          db_config = Base.configurations.resolve(config)
          db_config.validate!
          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless db_config.adapter
          ConnectionAdapters::PoolConfig.new(connection_name, db_config, role, shard)
        end

        def determine_owner_name(owner_name, config)
          if owner_name.is_a?(String) || owner_name.is_a?(Symbol)
            StringConnectionName.new(owner_name.to_s)
          elsif config.is_a?(Symbol)
            StringConnectionName.new(config.to_s)
          else
            owner_name
          end
        end
    end
  end
end

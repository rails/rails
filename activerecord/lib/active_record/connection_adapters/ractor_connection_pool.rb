# frozen_string_literal: true

# :markup: markdown

require "ractor/dispatch"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionPool # :nodoc:
      Lease = Struct.new(:connection, :sticky)

      # Dispatches schema cache lookups to the schema cache of this pool's
      # main-Ractor counterpart (not to whatever pool `ActiveRecord::Base`
      # currently resolves to). The full BoundSchemaReflection interface is
      # defined up front so lookups never pay `method_missing` dispatch.
      class SchemaCacheProxy
        def initialize(pool)
          @pool = pool
        end

        BoundSchemaReflection.public_instance_methods(false).each do |method_name|
          class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
            def #{method_name}(*args, **kwargs)
              @pool.dispatch_to_main_schema_cache(:#{method_name}, args, kwargs)
            end
          RUBY
        end
      end

      attr_reader :db_config, :role, :shard, :key

      def self.spec_for(pool, copy: true) # :nodoc:
        pool_config = pool.pool_config
        descriptor = pool_config.connection_descriptor
        spec = {
          db_config: pool_config.db_config,
          connection_name: descriptor.name.to_s.freeze,
          role: pool_config.role,
          shard: pool_config.shard,
          pool_token: RactorConnectionProxy.pool_token(pool),
        }
        copy ? ActiveSupport::Ractors.make_shareable(spec, copy: true) : spec
      end

      def self.for_spec(spec)
        pools = (ActiveSupport::Ractors[:active_record_ractor_pools] ||= Concurrent::Map.new)
        key = [spec.fetch(:connection_name), spec.fetch(:role), spec.fetch(:shard), spec.fetch(:pool_token)]
        pools.compute_if_absent(key) { new(spec) }
      end

      def initialize(spec)
        @db_config = spec.fetch(:db_config)
        @connection_name = spec.fetch(:connection_name).to_s.freeze
        @role = spec.fetch(:role)
        @shard = spec.fetch(:shard)
        @pool_token = spec.fetch(:pool_token)
        @key = [@connection_name, @role, @shard, @pool_token].freeze
      end

      def inspect
        "#<#{self.class.name} env_name=#{db_config.env_name.inspect} name=#{db_config.name.inspect} role=#{role.inspect} shard=#{shard.inspect}>"
      end

      def ==(other)
        self.class == other.class && key == other.key
      end
      alias :eql? :==

      def hash
        [self.class, key].hash
      end

      def connection_descriptor
        main_pool_value(:connection_descriptor)
      end

      def schema_reflection
        main_pool_value(:schema_reflection)
      end

      def schema_cache
        state.schema_cache ||= SchemaCacheProxy.new(self)
      end

      def dispatch_to_main_schema_cache(method_name, args, kwargs) # :nodoc:
        RactorConnectionProxy.dispatch_to_main_schema_cache(
          @connection_name, @role, @shard, method_name, args, kwargs,
          connection_token: connection_lease.connection&.connection_token, connection_pool: self
        )
      end

      def migration_context
        MigrationContext.new(migrations_paths, schema_migration, internal_metadata)
      end

      def migrations_paths
        db_config.migrations_paths || Migrator.migrations_paths
      end

      def schema_migration
        SchemaMigration.new(self)
      end

      def internal_metadata
        InternalMetadata.new(self)
      end

      def lease_connection
        lease = connection_lease
        lease.connection ||= checkout
        lease.sticky = true
        lease.connection
      end

      def permanent_lease?
        connection_lease.sticky.nil?
      end

      def active_connection?
        connection_lease.connection
      end
      alias :active_connection :active_connection?

      def release_connection(existing_lease = nil)
        lease = existing_lease || connection_lease
        if connection = lease.connection
          lease.connection = nil
          lease.sticky = nil
          checkin(connection)
          true
        else
          false
        end
      end

      def with_connection(prevent_permanent_checkout: false)
        lease = connection_lease
        sticky_was = lease.sticky
        lease.sticky = false if prevent_permanent_checkout

        if lease.connection
          begin
            yield lease.connection
          ensure
            lease.sticky = sticky_was if prevent_permanent_checkout && !sticky_was
          end
        else
          begin
            lease.connection = checkout
            yield lease.connection
          ensure
            lease.sticky = sticky_was if prevent_permanent_checkout && !sticky_was
            release_connection(lease) unless lease.sticky
          end
        end
      end

      def checkout(_checkout_timeout = nil)
        if pinned = state.pinned_connection
          return pinned
        end

        connection_token, profile = RactorConnectionProxy.checkout_connection(@connection_name, @role, @shard)
        connection = RactorConnectionProxy.new(self, connection_token, profile, db_config.configuration_hash)
        connection.lease
        connection.query_cache = query_cache
        connection
      end

      def checkin(connection)
        release_lease(connection)
        # The pinned proxy stays checked out (and leased to the pinning
        # thread) until unpin releases it.
        return if state.pinned_connection.equal?(connection)

        connection.expire if connection.in_use?
        connection.release_connection
      end

      # Mirrors ConnectionPool#pin_connection!: the main pool is pinned for
      # connection identity (every checkout yields the same physical
      # connection), while the pinned transaction is started here so it lives
      # on the worker-side proxy's transaction manager and worker
      # transactions nest as savepoints. The pinned proxy is shared by every
      # thread of this Ractor, like the pinned connection of a real pool.
      def pin_connection!(lock_thread)
        RactorConnectionProxy.pin_main_pool_connection(@connection_name, @role, @shard, lock_thread, connection_pool: self)
        state = self.state
        begin
          state.pinned_connection ||= (connection_lease.connection || checkout)
          state.pinned_depth += 1

          connection = state.pinned_connection
          connection.lock_thread = ActiveSupport::IsolatedExecutionState.context if lock_thread
          connection.pinned = true
          connection.begin_transaction joinable: false, _lazy: false
        rescue Exception
          # A leaked identity pin would hand the (possibly dirty) physical
          # connection to every later checkout.
          RactorConnectionProxy.unpin_main_pool_connection(@connection_name, @role, @shard, @pool_token, connection_pool: self)
          raise
        end
      end

      def unpin_connection!
        state = self.state
        raise "There isn't a pinned connection #{object_id}" unless state.pinned_connection

        connection = state.pinned_connection
        clean = true
        begin
          state.pinned_depth -= 1

          if connection.transaction_open?
            connection.rollback_transaction
          else
            # Something committed or rolled back the pinned transaction
            clean = false
            connection.reset!
          end
        ensure
          # Even when the rollback fails (e.g. the pinned physical connection
          # was discarded underneath us), the identity pin must be released or
          # every later checkout inherits the broken connection.
          if state.pinned_depth.zero?
            state.pinned_connection = nil
            connection.pinned = false
            connection.lock_thread = nil
            release_lease(connection)
            connection.expire if connection.in_use?
            connection.release_connection
          end
          RactorConnectionProxy.unpin_main_pool_connection(@connection_name, @role, @shard, @pool_token, connection_pool: self)
        end
        clean
      end

      # Backs `AbstractAdapter#throw_away!`.
      def remove(connection)
        release_lease(connection)
        connection.remove_connection
      end

      def connected?
        main_pool_value(:connected?)
      end

      def disconnect!
        release_connection
      end
      alias :flush! :disconnect!

      def disable_query_cache(dirties: true)
        cache = query_cache
        old_enabled, cache.enabled, old_dirties, cache.dirties = cache.enabled, false, cache.dirties, dirties
        begin
          yield
        ensure
          cache.enabled, cache.dirties = old_enabled, old_dirties
        end
      end

      def enable_query_cache
        cache = query_cache
        old_enabled, cache.enabled, old_dirties, cache.dirties = cache.enabled, true, cache.dirties, true
        begin
          yield
        ensure
          cache.enabled, cache.dirties = old_enabled, old_dirties
        end
      end

      def enable_query_cache!
        query_cache.enabled = true
        query_cache.dirties = true
      end

      def disable_query_cache!
        query_cache.enabled = false
        query_cache.dirties = true
      end

      def query_cache_enabled
        query_cache.enabled
      end

      def dirties_query_cache
        query_cache.dirties
      end

      def clear_query_cache
        state.query_cache_version.increment if state.pinned_connection
        query_cache.clear
      end

      def query_cache
        caches = (ActiveSupport::IsolatedExecutionState[:active_record_ractor_query_caches] ||= {})
        caches[key] ||= QueryCache::Store.new(state.query_cache_version, query_cache_max_size)
      end

      def pool_transaction_isolation_level
        ActiveSupport::IsolatedExecutionState[pool_transaction_isolation_level_key]
      end

      def pool_transaction_isolation_level=(isolation_level)
        ActiveSupport::IsolatedExecutionState[pool_transaction_isolation_level_key] = isolation_level
      end

      def with_pool_transaction_isolation_level(isolation_level, transaction_open)
        if !ActiveRecord.default_transaction_isolation_level.nil?
          begin
            if transaction_open && pool_transaction_isolation_level != ActiveRecord.default_transaction_isolation_level
              raise ActiveRecord::TransactionIsolationError, "cannot set default isolation level while transaction is open"
            end

            old_level = pool_transaction_isolation_level
            self.pool_transaction_isolation_level = isolation_level
            yield
          ensure
            self.pool_transaction_isolation_level = old_level
          end
        else
          yield
        end
      end

      def async_executor
        state.async_executor(self)
      end

      def build_async_executor # :nodoc:
        case ActiveRecord.async_query_executor
        when :multi_thread_pool
          if db_config.max_threads > 0
            Concurrent::ThreadPoolExecutor.new(
              name: "ActiveRecord-#{db_config.name}-ractor-async-query-executor",
              min_threads: db_config.min_threads,
              max_threads: db_config.max_threads,
              max_queue: db_config.max_queue,
              fallback_policy: :caller_runs
            )
          end
        when :global_thread_pool
          ActiveRecord.global_thread_pool_async_query_executor
        end
      end

      def schedule_query(future_result)
        if executor = async_executor
          executor.post { future_result.execute_or_skip }
          Thread.pass
        else
          future_result.execute_or_skip
        end
      end

      class State # :nodoc:
        attr_reader :query_cache_version
        attr_accessor :pinned_connection, :pinned_depth, :schema_cache

        def initialize
          @query_cache_version = Concurrent::AtomicFixnum.new
          @pinned_connection = nil
          @pinned_depth = 0
          @async_executor_lock = Mutex.new
          @async_executor_built = false
          @async_executor = nil
        end

        def async_executor(pool)
          @async_executor_lock.synchronize do
            unless @async_executor_built
              @async_executor_built = true
              @async_executor = pool.build_async_executor
            end
            @async_executor
          end
        end
      end

      def state # :nodoc:
        states = (ActiveSupport::Ractors[:active_record_ractor_pool_states] ||= Concurrent::Map.new)
        states.compute_if_absent(key) { State.new }
      end

      def query_cache_max_size # :nodoc:
        case size = db_config&.query_cache
        when 0, false
          nil
        when Integer
          size
        when nil
          QueryCache::DEFAULT_SIZE
        end
      end

      private
        def connection_lease
          leases = (ActiveSupport::IsolatedExecutionState[:active_record_ractor_connection_leases] ||= {})
          lease = leases[key] ||= Lease.new(nil, nil)
          if (connection = lease.connection) && !connection.holds_main_connection?
            lease.connection = nil
            lease.sticky = nil
          end
          lease
        end

        def release_lease(connection)
          lease = connection_lease
          if lease.connection.equal?(connection)
            lease.connection = nil
            lease.sticky = nil
          end
        end

        def pool_transaction_isolation_level_key
          "activerecord_pool_transaction_isolation_level_#{@db_config.name}"
        end

        def main_pool_value(method_name)
          RactorConnectionProxy.dispatch_to_main_pool(@connection_name, @role, @shard, method_name, [], {}, connection_pool: self)
        end

        def method_missing(name, *args, **kwargs, &block)
          return super if block

          RactorConnectionProxy.dispatch_to_main_pool(@connection_name, @role, @shard, name, args, kwargs, connection_pool: self)
        end

        def respond_to_missing?(_name, _include_private = false)
          true
        end
    end
  end
end

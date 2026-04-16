# frozen_string_literal: true

require "concurrent/map"
require "monitor"

require "active_record/connection_adapters/abstract/connection_pool/queue"
require "active_record/connection_adapters/abstract/connection_pool/reaper"

module ActiveRecord
  module ConnectionAdapters
    class NullPool # :nodoc:
      class NullConfig
        def method_missing(...)
          nil
        end
      end
      NULL_CONFIG = NullConfig.new

      def initialize
        super()
        @mutex = Mutex.new
        @server_version = nil
      end

      def server_version(connection) # :nodoc:
        @server_version || @mutex.synchronize { @server_version ||= connection.get_database_version }
      end

      def schema_reflection
        SchemaReflection.new(nil)
      end

      def schema_cache; end
      def query_cache; end
      def connection_descriptor; end
      def checkin(_); end
      def remove(_); end
      def async_executor; end

      def db_config
        NULL_CONFIG
      end

      def dirties_query_cache
        true
      end

      def pool_transaction_isolation_level; end
      def pool_transaction_isolation_level=(isolation_level)
        raise NotImplementedError, "This method should never be called"
      end
    end

    # = Active Record Connection Pool
    #
    # Connection pool base class for managing Active Record database
    # connections.
    #
    # == Introduction
    #
    # A connection pool synchronizes thread access to a limited number of
    # database connections. The basic idea is that each thread checks out a
    # database connection from the pool, uses that connection, and checks the
    # connection back in. ConnectionPool is completely thread-safe, and will
    # ensure that a connection cannot be used by two threads at the same time,
    # as long as ConnectionPool's contract is correctly followed. It will also
    # handle cases in which there are more threads than connections: if all
    # connections have been checked out, and a thread tries to checkout a
    # connection anyway, then ConnectionPool will wait until some other thread
    # has checked in a connection, or the +checkout_timeout+ has expired.
    #
    # == Obtaining (checking out) a connection
    #
    # Connections can be obtained and used from a connection pool in several
    # ways:
    #
    # 1. Simply use {ActiveRecord::Base.lease_connection}[rdoc-ref:ConnectionHandling#lease_connection].
    #    When you're done with the connection(s) and wish it to be returned to the pool, you call
    #    {ActiveRecord::Base.connection_handler.clear_active_connections!}[rdoc-ref:ConnectionAdapters::ConnectionHandler#clear_active_connections!].
    #    This is the default behavior for Active Record when used in conjunction with
    #    Action Pack's request handling cycle.
    # 2. Manually check out a connection from the pool with
    #    {ActiveRecord::Base.connection_pool.checkout}[rdoc-ref:#checkout]. You are responsible for
    #    returning this connection to the pool when finished by calling
    #    {ActiveRecord::Base.connection_pool.checkin(connection)}[rdoc-ref:#checkin].
    # 3. Use {ActiveRecord::Base.connection_pool.with_connection(&block)}[rdoc-ref:#with_connection], which
    #    obtains a connection, yields it as the sole argument to the block,
    #    and returns it to the pool after the block completes.
    #
    # Connections in the pool are actually AbstractAdapter objects (or objects
    # compatible with AbstractAdapter's interface).
    #
    # While a thread has a connection checked out from the pool using one of the
    # above three methods, that connection will automatically be the one used
    # by ActiveRecord queries executing on that thread. It is not required to
    # explicitly pass the checked out connection to \Rails models or queries, for
    # example.
    #
    # == Options
    #
    # There are several connection-pooling-related options that you can add to
    # your database connection configuration:
    #
    # * +checkout_timeout+: number of seconds to wait for a connection to
    #   become available before giving up and raising a timeout error (default
    #   5 seconds).
    # * +idle_timeout+: number of seconds that a connection will be kept
    #   unused in the pool before it is automatically disconnected (default
    #   300 seconds). Set this to zero to keep connections forever.
    # * +keepalive+: number of seconds between keepalive checks if the
    #   connection has been idle (default 600 seconds).
    # * +max_age+: number of seconds the pool will allow the connection to
    #   exist before retiring it at next checkin. (default Float::INFINITY).
    # * +max_connections+: maximum number of connections the pool may manage (default 5).
    #   Set to +nil+ or -1 for unlimited connections.
    # * +min_connections+: minimum number of connections the pool will open and maintain (default 0).
    # * +pool_jitter+: maximum reduction factor to apply to +max_age+ and
    #   +keepalive+ intervals (default 0.2; range 0.0-1.0).
    #
    #--
    # Synchronization policy:
    # * all public methods can be called outside +synchronize+
    # * access to these instance variables needs to be in +synchronize+:
    #   * @connections
    #   * @now_connecting
    #   * @maintaining
    # * private methods that require being called in a +synchronize+ blocks
    #   are now explicitly documented
    class ConnectionPool
      # Prior to 3.3.5, WeakKeyMap had a use after free bug
      # https://bugs.ruby-lang.org/issues/20688
      if ObjectSpace.const_defined?(:WeakKeyMap) && Gem::Version.new(RUBY_VERSION) >= "3.3.5"
        WeakThreadKeyMap = ObjectSpace::WeakKeyMap
      else
        class WeakThreadKeyMap # :nodoc:
          # FIXME: On 3.3 we could use ObjectSpace::WeakKeyMap
          # but it currently causes GC crashes: https://github.com/byroot/rails/pull/3
          def initialize
            @map = {}
          end

          def clear
            @map.clear
          end

          def [](key)
            @map[key]
          end

          def []=(key, value)
            @map.select! { |c, _| c&.alive? }
            @map[key] = value
          end
        end
      end

      class Lease # :nodoc:
        attr_accessor :connection, :sticky

        def initialize
          @connection = nil
          @sticky = nil
        end

        def release
          conn = @connection
          @connection = nil
          @sticky = nil
          conn
        end

        def clear(connection)
          if @connection == connection
            @connection = nil
            @sticky = nil
            true
          else
            false
          end
        end
      end

      if RUBY_ENGINE == "ruby"
        # Thanks to the GVL, the LeaseRegistry doesn't need to be synchronized on MRI
        class LeaseRegistry < WeakThreadKeyMap # :nodoc:
          def [](context)
            super || (self[context] = Lease.new)
          end
        end
      else
        class LeaseRegistry # :nodoc:
          def initialize
            @mutex = Mutex.new
            @map = WeakThreadKeyMap.new
          end

          def [](context)
            @mutex.synchronize do
              @map[context] ||= Lease.new
            end
          end

          def clear
            @mutex.synchronize do
              @map.clear
            end
          end
        end
      end

      module ExecutorHooks # :nodoc:
        class << self
          def run
            # noop
          end

          def complete(_)
            ActiveRecord::Base.connection_handler.each_connection_pool do |pool|
              if (connection = pool.active_connection?)
                transaction = connection.current_transaction
                if transaction.closed? || !transaction.joinable?
                  pool.release_connection
                end
              end
            end
          end
        end
      end

      class << self
        def install_executor_hooks(executor = ActiveSupport::Executor)
          executor.register_hook(ExecutorHooks)
        end
      end

      include MonitorMixin
      prepend QueryCache::ConnectionPoolConfiguration

      attr_accessor :automatic_reconnect, :checkout_timeout
      attr_reader :db_config, :max_connections, :min_connections, :max_age, :keepalive, :reaper, :pool_config, :async_executor, :role, :shard
      alias :size :max_connections

      delegate :schema_reflection, :server_version, to: :pool_config

      # Creates a new ConnectionPool object. +pool_config+ is a PoolConfig
      # object which describes database connection information (e.g. adapter,
      # host name, username, password, etc), as well as the maximum size for
      # this ConnectionPool.
      #
      # The default ConnectionPool maximum size is 5.
      def initialize(pool_config)
        super()

        @pool_config = pool_config
        @db_config = pool_config.db_config
        @role = pool_config.role
        @shard = pool_config.shard

        @checkout_timeout = db_config.checkout_timeout
        @idle_timeout = db_config.idle_timeout
        @max_connections = db_config.max_connections
        @min_connections = db_config.min_connections
        @max_age = db_config.max_age
        @keepalive = db_config.keepalive

        # This variable tracks the cache of threads mapped to reserved connections, with the
        # sole purpose of speeding up the +connection+ method. It is not the authoritative
        # registry of which thread owns which connection. Connection ownership is tracked by
        # the +connection.owner+ attr on each +connection+ instance.
        # The invariant works like this: if there is mapping of <tt>thread => conn</tt>,
        # then that +thread+ does indeed own that +conn+. However, an absence of such
        # mapping does not mean that the +thread+ doesn't own the said connection. In
        # that case +conn.owner+ attr should be consulted.
        # Access and modification of <tt>@leases</tt> does not require
        # synchronization.
        @leases = LeaseRegistry.new

        @connections         = []
        @automatic_reconnect = true

        # Connection pool allows for concurrent (outside the main +synchronize+ section)
        # establishment of new connections. This variable tracks the number of threads
        # currently in the process of independently establishing connections to the DB.
        @now_connecting = 0

        # Sometimes otherwise-idle connections are temporarily held by the Reaper for
        # maintenance. This variable tracks the number of connections currently in that
        # state -- if a thread requests a connection and there are none available, it
        # will await any in-maintenance connections in preference to creating a new one.
        @maintaining = 0

        @threads_blocking_new_connections = 0

        @available = ConnectionLeasingQueue.new self
        @pinned_connection = nil
        @pinned_connections_depth = 0

        @async_executor = build_async_executor

        @schema_cache = nil

        @activated = false
        @original_context = ActiveSupport::IsolatedExecutionState.context

        @reaper_lock = Monitor.new
        @reaper = Reaper.new(self, db_config.reaping_frequency)
        @reaper.run
      end

      def inspect # :nodoc:
        name_field = " name=#{name_inspect}" if name_inspect
        shard_field = " shard=#{shard_inspect}" if shard_inspect

        "#<#{self.class.name} env_name=#{db_config.env_name.inspect}#{name_field} role=#{role.inspect}#{shard_field}>"
      end

      def schema_cache
        @schema_cache ||= BoundSchemaReflection.new(schema_reflection, self)
      end

      def schema_reflection=(schema_reflection)
        pool_config.schema_reflection = schema_reflection
        @schema_cache = nil
      end

      def migration_context # :nodoc:
        MigrationContext.new(migrations_paths, schema_migration, internal_metadata)
      end

      def migrations_paths # :nodoc:
        db_config.migrations_paths || Migrator.migrations_paths
      end

      def schema_migration # :nodoc:
        SchemaMigration.new(self)
      end

      def internal_metadata # :nodoc:
        InternalMetadata.new(self)
      end

      def activate
        @activated = true
      end

      def activated?
        @activated
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #lease_connection can be called any number of times; the connection is
      # held in a cache keyed by a thread.
      def lease_connection
        lease = connection_lease
        lease.connection ||= checkout
        lease.sticky = true
        lease.connection
      end

      def permanent_lease? # :nodoc:
        connection_lease.sticky.nil?
      end

      def pin_connection!(lock_thread) # :nodoc:
        @pinned_connection ||= (connection_lease&.connection || checkout)
        @pinned_connections_depth += 1

        # Any leased connection must be in @connections otherwise
        # some methods like #connected? won't behave correctly
        unless @connections.include?(@pinned_connection)
          @connections << @pinned_connection
        end

        @pinned_connection.lock_thread = ActiveSupport::IsolatedExecutionState.context if lock_thread
        @pinned_connection.pinned = true
        @pinned_connection.begin_transaction joinable: false, _lazy: false
      end

      def unpin_connection! # :nodoc:
        raise "There isn't a pinned connection #{object_id}" unless @pinned_connection

        clean = true
        @pinned_connection.lock.synchronize do
          @pinned_connections_depth -= 1
          connection = @pinned_connection
          @pinned_connection = nil if @pinned_connections_depth.zero?

          if connection.transaction_open?
            connection.rollback_transaction
          else
            # Something committed or rolled back the transaction
            clean = false
            connection.reset!
          end

          if @pinned_connection.nil?
            connection.pinned = false
            connection.steal!
            connection.lock_thread = nil
            checkin(connection)
          end
        end

        clean
      end

      def connection_descriptor # :nodoc:
        pool_config.connection_descriptor
      end

      # Returns true if there is an open connection being used for the current thread.
      #
      # This method only works for connections that have been obtained through
      # #lease_connection or #with_connection methods. Connections obtained through
      # #checkout will not be detected by #active_connection?
      def active_connection?
        connection_lease.connection
      end
      alias_method :active_connection, :active_connection? # :nodoc:

      # Signal that the thread is finished with the current connection.
      # #release_connection releases the connection-thread association
      # and returns the connection to the pool.
      #
      # This method only works for connections that have been obtained through
      # #lease_connection or #with_connection methods, connections obtained through
      # #checkout will not be automatically released.
      def release_connection(existing_lease = nil)
        return if self.discarded?

        if conn = connection_lease.release
          checkin conn
          return true
        end
        false
      end

      # Yields a connection from the connection pool to the block. If no connection
      # is already checked out by the current thread, a connection will be checked
      # out from the pool, yielded to the block, and then returned to the pool when
      # the block is finished. If a connection has already been checked out on the
      # current thread, such as via #lease_connection or #with_connection, that existing
      # connection will be the one yielded and it will not be returned to the pool
      # automatically at the end of the block; it is expected that such an existing
      # connection will be properly returned to the pool by the code that checked
      # it out.
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
            yield lease.connection = checkout
          ensure
            lease.sticky = sticky_was if prevent_permanent_checkout && !sticky_was
            release_connection(lease) unless lease.sticky
          end
        end
      end

      def with_pool_transaction_isolation_level(isolation_level, transaction_open, &block) # :nodoc:
        if !ActiveRecord.default_transaction_isolation_level.nil?
          begin
            if transaction_open && self.pool_transaction_isolation_level != ActiveRecord.default_transaction_isolation_level
              raise ActiveRecord::TransactionIsolationError, "cannot set default isolation level while transaction is open"
            end

            old_level = self.pool_transaction_isolation_level
            self.pool_transaction_isolation_level = isolation_level
            yield
          ensure
            self.pool_transaction_isolation_level = old_level
          end
        else
          yield
        end
      end

      # Returns true if a connection has already been opened.
      def connected?
        synchronize { @connections.any?(&:connected?) }
      end

      # Returns an array containing the connections currently in the pool.
      # Access to the array does not require synchronization on the pool because
      # the array is newly created and not retained by the pool.
      #
      # However; this method bypasses the ConnectionPool's thread-safe connection
      # access pattern. A returned connection may be owned by another thread,
      # unowned, or by happen-stance owned by the calling thread.
      #
      # Calling methods on a connection without ownership is subject to the
      # thread-safety guarantees of the underlying method. Many of the methods
      # on connection adapter classes are inherently multi-thread unsafe.
      def connections
        synchronize { @connections.dup }
      end

      # Disconnects all connections in the pool, and clears the pool.
      #
      # Raises:
      # - ActiveRecord::ExclusiveConnectionTimeoutError if unable to gain ownership of all
      #   connections in the pool within a timeout interval (default duration is
      #   <tt>spec.db_config.checkout_timeout * 2</tt> seconds).
      def disconnect(raise_on_acquisition_timeout = true)
        @reaper_lock.synchronize do
          return if self.discarded?

          with_exclusively_acquired_all_connections(raise_on_acquisition_timeout) do
            synchronize do
              return if self.discarded?
              @connections.each do |conn|
                if conn.in_use?
                  conn.steal!
                  checkin conn
                end
                conn.disconnect!
              end
              @connections = @pinned_connection ? [@pinned_connection] : []
              @leases.clear
              @available.clear

              # Stop maintaining the minimum size until reactivated
              @activated = false
            end
          end
        end
      end

      # Disconnects all connections in the pool, and clears the pool.
      #
      # The pool first tries to gain ownership of all connections. If unable to
      # do so within a timeout interval (default duration is
      # <tt>spec.db_config.checkout_timeout * 2</tt> seconds), then the pool is forcefully
      # disconnected without any regard for other connection owning threads.
      def disconnect!
        disconnect(false)
      end

      # Discards all connections in the pool (even if they're currently
      # leased!), along with the pool itself. Any further interaction with the
      # pool (except #spec and #schema_cache) is undefined.
      #
      # See AbstractAdapter#discard!
      def discard! # :nodoc:
        @reaper_lock.synchronize do
          synchronize do
            return if self.discarded?
            @connections.each do |conn|
              conn.discard!
            end
            @connections = @available = @leases = nil
          end
        end
      end

      def discarded? # :nodoc:
        @connections.nil?
      end

      def maintainable? # :nodoc:
        synchronize do
          @connections&.size&.> 0 || (activated? && @min_connections > 0)
        end
      end

      def reaper_lock(&block) # :nodoc:
        @reaper_lock.synchronize(&block)
      end

      # Clears reloadable connections from the pool and re-connects connections that
      # require reloading.
      #
      # Raises:
      # - ActiveRecord::ExclusiveConnectionTimeoutError if unable to gain ownership of all
      #   connections in the pool within a timeout interval (default duration is
      #   <tt>spec.db_config.checkout_timeout * 2</tt> seconds).
      def clear_reloadable_connections(raise_on_acquisition_timeout = true)
        with_exclusively_acquired_all_connections(raise_on_acquisition_timeout) do
          synchronize do
            @connections.each do |conn|
              if conn.in_use?
                conn.steal!
                checkin conn
              end
              conn.disconnect! if conn.requires_reloading?
            end
            @connections.delete_if(&:requires_reloading?)
            @available.clear
          end
        end
      end

      # Clears reloadable connections from the pool and re-connects connections that
      # require reloading.
      #
      # The pool first tries to gain ownership of all connections. If unable to
      # do so within a timeout interval (default duration is
      # <tt>spec.db_config.checkout_timeout * 2</tt> seconds), then the pool forcefully
      # clears the cache and reloads connections without any regard for other
      # connection owning threads.
      def clear_reloadable_connections!
        clear_reloadable_connections(false)
      end

      # Check-out a database connection from the pool, indicating that you want
      # to use it. You should call #checkin when you no longer need this.
      #
      # This is done by either returning and leasing existing connection, or by
      # creating a new connection and leasing it.
      #
      # If all connections are leased and the pool is at capacity (meaning the
      # number of currently leased connections is greater than or equal to the
      # size limit set), an ActiveRecord::ConnectionTimeoutError exception will be raised.
      #
      # Returns: an AbstractAdapter object.
      #
      # Raises:
      # - ActiveRecord::ConnectionTimeoutError no connection can be obtained from the pool.
      def checkout(checkout_timeout = @checkout_timeout)
        return checkout_and_verify(acquire_connection(checkout_timeout)) unless @pinned_connection

        @pinned_connection.lock.synchronize do
          synchronize do
            # The pinned connection may have been cleaned up before we synchronized, so check if it is still present
            if @pinned_connection
              @pinned_connection.verify

              # Any leased connection must be in @connections otherwise
              # some methods like #connected? won't behave correctly
              unless @connections.include?(@pinned_connection)
                @connections << @pinned_connection
              end

              @pinned_connection
            else
              checkout_and_verify(acquire_connection(checkout_timeout))
            end
          end
        end
      end

      # Check-in a database connection back into the pool, indicating that you
      # no longer need this connection.
      #
      # +conn+: an AbstractAdapter object, which was obtained by earlier by
      # calling #checkout on this pool.
      def checkin(conn)
        return if @pinned_connection.equal?(conn)

        conn.lock.synchronize do
          synchronize do
            connection_lease.clear(conn)
            conn.expire
            @available.add conn
          end
        end
      end

      # Remove a connection from the connection pool. The connection will
      # remain open and active but will no longer be managed by this pool.
      def remove(conn)
        needs_new_connection = false

        synchronize do
          remove_connection_from_thread_cache conn

          @connections.delete conn
          @available.delete conn

          # @available.any_waiting? => true means that prior to removing this
          # conn, the pool was at its max size (@connections.size == @max_connections).
          # This would mean that any threads stuck waiting in the queue wouldn't
          # know they could checkout_new_connection, so let's do it for them.
          # Because condition-wait loop is encapsulated in the Queue class
          # (that in turn is oblivious to ConnectionPool implementation), threads
          # that are "stuck" there are helpless. They have no way of creating
          # new connections and are completely reliant on us feeding available
          # connections into the Queue.
          needs_new_connection = @available.num_waiting > @maintaining
        end

        # This is intentionally done outside of the synchronized section as we
        # would like not to hold the main mutex while checking out new connections.
        # Thus there is some chance that needs_new_connection information is now
        # stale, we can live with that (bulk_make_new_connections will make
        # sure not to exceed the pool's @max_connections limit).
        bulk_make_new_connections(1) if needs_new_connection
      end

      # Recover lost connections for the pool. A lost connection can occur if
      # a programmer forgets to checkin a connection at the end of a thread
      # or a thread dies unexpectedly.
      def reap
        stale_connections = synchronize do
          return if self.discarded?
          @connections.select do |conn|
            conn.in_use? && !conn.owner.alive?
          end.each do |conn|
            conn.steal!
          end
        end

        stale_connections.each do |conn|
          if conn.active?
            conn.reset!
            checkin conn
          else
            remove conn
          end
        end
      end

      # Disconnect all connections that have been idle for at least
      # +minimum_idle+ seconds. Connections currently checked out, or that were
      # checked in less than +minimum_idle+ seconds ago, are unaffected.
      def flush(minimum_idle = @idle_timeout)
        return if minimum_idle.nil?

        removed_connections = synchronize do
          return if self.discarded?

          idle_connections = @connections.select do |conn|
            !conn.in_use? && conn.seconds_idle >= minimum_idle
          end.sort_by { |conn| -conn.seconds_idle } # sort longest idle first

          # Don't go below our configured pool minimum unless we're flushing
          # everything
          idles_to_retain =
            if minimum_idle > 0
              @min_connections - (@connections.size - idle_connections.size)
            else
              0
            end

          if idles_to_retain > 0
            idle_connections.pop idles_to_retain
          end

          idle_connections.each do |conn|
            conn.lease

            @available.delete conn
            @connections.delete conn
          end
        end

        removed_connections.each do |conn|
          conn.disconnect!
        end
      end

      # Disconnect all currently idle connections. Connections currently checked
      # out are unaffected. The pool will stop maintaining its minimum size until
      # it is reactivated (such as by a subsequent checkout).
      def flush!
        reap
        flush(-1)

        # Stop maintaining the minimum size until reactivated
        @activated = false
      end

      # Ensure that the pool contains at least the configured minimum number of
      # connections.
      def prepopulate
        need_new_connections = nil

        synchronize do
          return if self.discarded?

          # We don't want to start prepopulating until we know the pool is wanted,
          # so we can avoid maintaining full pools in one-off scripts etc.
          return unless @activated

          need_new_connections = @connections.size < @min_connections
        end

        if need_new_connections
          while new_conn = try_to_checkout_new_connection { @connections.size < @min_connections }
            new_conn.allow_preconnect = true
            checkin(new_conn)
          end
        end
      end

      def retire_old_connections(max_age = @max_age)
        max_age ||= Float::INFINITY

        sequential_maintenance -> c { c.connection_age&.>= c.pool_jitter(max_age) } do |conn|
          # Disconnect, then return the adapter to the pool. Preconnect will
          # handle the rest.
          conn.disconnect!
        end
      end

      # Preconnect all connections in the pool. This saves pool users from
      # having to wait for a connection to be established when first using it
      # after checkout.
      def preconnect
        sequential_maintenance -> c { (!c.connected? || !c.verified?) && c.allow_preconnect } do |conn|
          conn.connect!
        rescue
          # Wholesale rescue: there's nothing we can do but move on. The
          # connection will go back to the pool, and the next consumer will
          # presumably try to connect again -- which will either work, or
          # fail and they'll be able to report the exception.
        end
      end

      # Prod any connections that have been idle for longer than the configured
      # keepalive time. This will incidentally verify the connection is still
      # alive, but the main purpose is to show the server (and any intermediate
      # network hops) that we're still here and using the connection.
      def keep_alive(threshold = @keepalive)
        return if threshold.nil?

        sequential_maintenance -> c { (c.seconds_since_last_activity || 0) > c.pool_jitter(threshold) } do |conn|
          # conn.active? will cause some amount of network activity, which is all
          # we need to provide a keepalive signal.
          #
          # If it returns false, the connection is already broken; disconnect,
          # so it can be found and repaired.
          conn.disconnect! unless conn.active?
        end
      end

      # Immediately mark all current connections as due for replacement,
      # equivalent to them having reached +max_age+ -- even if there is
      # no +max_age+ configured.
      def recycle!
        synchronize do
          return if self.discarded?

          @connections.each do |conn|
            conn.force_retirement
          end
        end

        retire_old_connections
      end

      def num_waiting_in_queue # :nodoc:
        @available.num_waiting
      end

      def num_available_in_queue # :nodoc:
        @available.size
      end

      # Returns the connection pool's usage statistic.
      #
      #    ActiveRecord::Base.connection_pool.stat # => { size: 15, connections: 1, busy: 1, dead: 0, idle: 0, waiting: 0, checkout_timeout: 5 }
      def stat
        synchronize do
          {
            size: size,
            connections: @connections.size,
            busy: @connections.count { |c| c.in_use? && c.owner.alive? },
            dead: @connections.count { |c| c.in_use? && !c.owner.alive? },
            idle: @connections.count { |c| !c.in_use? },
            waiting: num_waiting_in_queue,
            checkout_timeout: checkout_timeout
          }
        end
      end

      def schedule_query(future_result) # :nodoc:
        @async_executor.post { future_result.execute_or_skip }
        Thread.pass
      end

      def new_connection # :nodoc:
        connection = db_config.new_connection
        connection.pool = self
        connection
      rescue ConnectionNotEstablished => ex
        raise ex.set_pool(self)
      end

      def pool_transaction_isolation_level
        isolation_level_key = "activerecord_pool_transaction_isolation_level_#{db_config.name}"
        ActiveSupport::IsolatedExecutionState[isolation_level_key]
      end

      def pool_transaction_isolation_level=(isolation_level)
        isolation_level_key = "activerecord_pool_transaction_isolation_level_#{db_config.name}"
        ActiveSupport::IsolatedExecutionState[isolation_level_key] = isolation_level
      end

      private
        def connection_lease
          @leases[ActiveSupport::IsolatedExecutionState.context]
        end

        def build_async_executor
          case ActiveRecord.async_query_executor
          when :multi_thread_pool
            if @db_config.max_threads > 0
              name_with_shard = [name_inspect, shard_inspect].join("-").tr("_", "-")
              Concurrent::ThreadPoolExecutor.new(
                name: "ActiveRecord-#{name_with_shard}-async-query-executor",
                min_threads: @db_config.min_threads,
                max_threads: @db_config.max_threads,
                max_queue: @db_config.max_queue,
                fallback_policy: :caller_runs
              )
            end
          when :global_thread_pool
            ActiveRecord.global_thread_pool_async_query_executor
          end
        end

        # Perform maintenance work on pool connections. This method will
        # select a connection to work on by calling the +candidate_selector+
        # proc while holding the pool lock. If a connection is selected, it
        # will be checked out for maintenance and passed to the
        # +maintenance_work+ proc. The connection will always be returned to
        # the pool after the proc completes.
        #
        # If the pool has async threads, all work will be scheduled there.
        # Otherwise, this method will block until all work is complete.
        #
        # Each connection will only be processed once per call to this method,
        # but (particularly in the async case) there is no protection against
        # a second call to this method starting to work through the list
        # before the first call has completed. (Though regular pool behavior
        # will prevent two instances from working on the same specific
        # connection at the same time.)
        def sequential_maintenance(candidate_selector, &maintenance_work)
          # This hash doesn't need to be synchronized, because it's only
          # used by one thread at a time: the +perform_work+ block gives
          # up its right to +connections_visited+ when it schedules the
          # next iteration.
          connections_visited = Hash.new(false)
          connections_visited.compare_by_identity

          perform_work = lambda do
            connection_to_maintain = nil

            synchronize do
              unless self.discarded?
                if connection_to_maintain = @connections.select { |conn| !conn.in_use? }.select(&candidate_selector).sort_by(&:seconds_idle).find { |conn| !connections_visited[conn] }
                  checkout_for_maintenance connection_to_maintain
                end
              end
            end

            if connection_to_maintain
              connections_visited[connection_to_maintain] = true

              # If we're running async, we can schedule the next round of work
              # as soon as we've grabbed a connection to work on.
              @async_executor&.post(&perform_work)

              begin
                maintenance_work.call connection_to_maintain
              ensure
                return_from_maintenance connection_to_maintain
              end

              true
            end
          end

          if @async_executor
            @async_executor.post(&perform_work)
          else
            nil while perform_work.call
          end
        end

        # Directly check a specific connection out of the pool. Skips callbacks.
        #
        # The connection must later either #return_from_maintenance or
        # #remove_from_maintenance, or the pool will hang.
        def checkout_for_maintenance(conn)
          synchronize do
            @maintaining += 1
            @available.delete(conn)
            conn.lease
            conn
          end
        end

        # Return a connection to the pool after it has been checked out for
        # maintenance. Does not update the connection's idle time, and skips
        # callbacks.
        #--
        # We assume that a connection that has required maintenance is less
        # desirable (either it's been idle for a long time, or it was just
        # created and hasn't been used yet). We'll put it at the back of the
        # queue.
        def return_from_maintenance(conn)
          synchronize do
            conn.expire(false)
            @available.add_back(conn)
            @maintaining -= 1
          end
        end

        # Remove a connection from the pool after it has been checked out for
        # maintenance. It will be automatically replaced with a new connection if
        # necessary.
        def remove_from_maintenance(conn)
          synchronize do
            @maintaining -= 1
            remove conn
          end
        end

        #--
        # this is unfortunately not concurrent
        def bulk_make_new_connections(num_new_conns_needed)
          num_new_conns_needed.times do
            # try_to_checkout_new_connection will not exceed pool's @max_connections limit
            if new_conn = try_to_checkout_new_connection
              # make the new_conn available to the starving threads stuck @available Queue
              checkin(new_conn)
            end
          end
        end

        # Take control of all existing connections so a "group" action such as
        # reload/disconnect can be performed safely. It is no longer enough to
        # wrap it in +synchronize+ because some pool's actions are allowed
        # to be performed outside of the main +synchronize+ block.
        def with_exclusively_acquired_all_connections(raise_on_acquisition_timeout = true)
          @reaper_lock.synchronize do
            with_new_connections_blocked do
              attempt_to_checkout_all_existing_connections(raise_on_acquisition_timeout)
              yield
            end
          end
        end

        def attempt_to_checkout_all_existing_connections(raise_on_acquisition_timeout = true)
          collected_conns = synchronize do
            reap # No need to wait for dead owners

            # account for our own connections
            @connections.select { |conn| conn.owner == ActiveSupport::IsolatedExecutionState.context }
          end

          newly_checked_out = []
          timeout_time      = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (@checkout_timeout * 2)

          @available.with_a_bias_for(ActiveSupport::IsolatedExecutionState.context) do
            loop do
              synchronize do
                return if collected_conns.size == @connections.size && @now_connecting == 0

                remaining_timeout = timeout_time - Process.clock_gettime(Process::CLOCK_MONOTONIC)
                remaining_timeout = 0 if remaining_timeout < 0
                conn = checkout_for_exclusive_access(remaining_timeout)
                collected_conns   << conn
                newly_checked_out << conn
              end
            end
          end
        rescue ExclusiveConnectionTimeoutError
          # <tt>raise_on_acquisition_timeout == false</tt> means we are directed to ignore any
          # timeouts and are expected to just give up: we've obtained as many connections
          # as possible, note that in a case like that we don't return any of the
          # +newly_checked_out+ connections.

          if raise_on_acquisition_timeout
            release_newly_checked_out = true
            raise
          end
        rescue Exception # if something else went wrong
          # this can't be a "naked" rescue, because we have should return conns
          # even for non-StandardErrors
          release_newly_checked_out = true
          raise
        ensure
          if release_newly_checked_out && newly_checked_out
            # releasing only those conns that were checked out in this method, conns
            # checked outside this method (before it was called) are not for us to release
            newly_checked_out.each { |conn| checkin(conn) }
          end
        end

        #--
        # Must be called in a synchronize block.
        def checkout_for_exclusive_access(checkout_timeout)
          checkout(checkout_timeout)
        rescue ConnectionTimeoutError
          # this block can't be easily moved into attempt_to_checkout_all_existing_connections's
          # rescue block, because doing so would put it outside of synchronize section, without
          # being in a critical section thread_report might become inaccurate
          msg = +"could not obtain ownership of all database connections in #{checkout_timeout} seconds"

          thread_report = []
          @connections.each do |conn|
            unless conn.owner == ActiveSupport::IsolatedExecutionState.context
              thread_report << "#{conn} is owned by #{conn.owner}"
            end
          end

          msg << " (#{thread_report.join(', ')})" if thread_report.any?

          raise ExclusiveConnectionTimeoutError.new(msg, connection_pool: self)
        end

        def with_new_connections_blocked
          synchronize do
            @threads_blocking_new_connections += 1
          end

          yield
        ensure
          num_new_conns_required = 0

          synchronize do
            @threads_blocking_new_connections -= 1

            if @threads_blocking_new_connections.zero?
              @available.clear

              num_new_conns_required = num_waiting_in_queue

              @connections.each do |conn|
                next if conn.in_use?

                @available.add conn
                num_new_conns_required -= 1
              end
            end
          end

          bulk_make_new_connections(num_new_conns_required) if num_new_conns_required > 0
        end

        # Acquire a connection by one of 1) immediately removing one
        # from the queue of available connections, 2) creating a new
        # connection if the pool is not at capacity, 3) waiting on the
        # queue for a connection to become available.
        #
        # Raises:
        # - ActiveRecord::ConnectionTimeoutError if a connection could not be acquired
        #
        #--
        # Implementation detail: the connection returned by +acquire_connection+
        # will already be "+connection.lease+ -ed" to the current thread.
        def acquire_connection(checkout_timeout)
          # NOTE: we rely on <tt>@available.poll</tt> and +try_to_checkout_new_connection+ to
          # +conn.lease+ the returned connection (and to do this in a +synchronized+
          # section). This is not the cleanest implementation, as ideally we would
          # <tt>synchronize { conn.lease }</tt> in this method, but by leaving it to <tt>@available.poll</tt>
          # and +try_to_checkout_new_connection+ we can piggyback on +synchronize+ sections
          # of the said methods and avoid an additional +synchronize+ overhead.
          if conn = @available.poll || try_to_queue_for_background_connection(checkout_timeout) || try_to_checkout_new_connection
            conn
          else
            reap
            # Retry after reaping, which may return an available connection,
            # remove an inactive connection, or both
            if conn = @available.poll || try_to_queue_for_background_connection(checkout_timeout) || try_to_checkout_new_connection
              conn
            else
              @available.poll(checkout_timeout)
            end
          end
        rescue ConnectionTimeoutError => ex
          raise ex.set_pool(self)
        end

        #--
        # If new connections are already being established in the background,
        # and there are fewer threads already waiting than the number of
        # upcoming connections, we can just get in queue and wait to be handed a
        # connection. This avoids us overshooting the required connection count
        # by starting a new connection ourselves, and is likely to be faster
        # too (because at least some of the time it takes to establish a new
        # connection must have already passed).
        #
        # If background connections are available, this method will block and
        # return a connection. If no background connections are available, it
        # will immediately return +nil+.
        def try_to_queue_for_background_connection(checkout_timeout)
          return unless @maintaining > 0

          synchronize do
            return unless @maintaining > @available.num_waiting

            # We are guaranteed the "maintaining" thread will return its promised
            # connection within one maintenance-unit of time. Thus we can safely
            # do a blocking wait with (functionally) no timeout.
            @available.poll(100)
          end
        end

        #--
        # if owner_thread param is omitted, this must be called in synchronize block
        def remove_connection_from_thread_cache(conn, owner_thread = conn.owner)
          if owner_thread
            @leases[owner_thread].clear(conn)
          end
        end
        alias_method :release, :remove_connection_from_thread_cache

        # If the pool is not at a <tt>@max_connections</tt> limit, establish new connection. Connecting
        # to the DB is done outside main synchronized section.
        #
        # If a block is supplied, it is an additional constraint (checked while holding the
        # pool lock) on whether a new connection should be established.
        #--
        # Implementation constraint: a newly established connection returned by this
        # method must be in the +.leased+ state.
        def try_to_checkout_new_connection
          # first in synchronized section check if establishing new conns is allowed
          # and increment @now_connecting, to prevent overstepping this pool's @max_connections
          # constraint
          do_checkout = synchronize do
            return if self.discarded?

            if @threads_blocking_new_connections.zero? && (@max_connections.nil? || (@connections.size + @now_connecting) < @max_connections) && (!block_given? || yield)
              if @connections.size > 0 || @original_context != ActiveSupport::IsolatedExecutionState.context
                @activated = true
              end

              @now_connecting += 1
            end
          end
          if do_checkout
            begin
              # if successfully incremented @now_connecting establish new connection
              # outside of synchronized section
              conn = checkout_new_connection
            ensure
              synchronize do
                @now_connecting -= 1
                if conn
                  if self.discarded?
                    conn.discard!
                  else
                    adopt_connection(conn)
                    # returned conn needs to be already leased
                    conn.lease
                  end
                end
              end
            end
          end
        end

        def adopt_connection(conn)
          conn.pool = self
          @connections << conn

          # We just created the first connection, it's time to load the schema
          # cache if that wasn't eagerly done before
          if @schema_cache.nil? && ActiveRecord.lazily_load_schema_cache
            schema_cache.load!
          end
        end

        def checkout_new_connection
          raise ConnectionNotEstablished unless @automatic_reconnect
          new_connection
        end

        def checkout_and_verify(c)
          c.clean!
        rescue Exception
          remove c
          c.disconnect!
          raise
        end

        def name_inspect
          db_config.name.inspect unless db_config.name == "primary"
        end

        def shard_inspect
          shard.inspect unless shard == :default
        end
    end
  end
end

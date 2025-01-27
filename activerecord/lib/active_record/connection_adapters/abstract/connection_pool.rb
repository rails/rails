# frozen_string_literal: true

require "concurrent/map"
require "monitor"

require "active_record/connection_adapters/abstract/connection_pool/queue"
require "active_record/connection_adapters/abstract/connection_pool/reaper"

module ActiveRecord
  module ConnectionAdapters
    module AbstractPool # :nodoc:
    end

    class NullPool # :nodoc:
      include ConnectionAdapters::AbstractPool

      class NullConfig # :nodoc:
        def method_missing(...)
          nil
        end
      end
      NULL_CONFIG = NullConfig.new # :nodoc:

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
    # * +pool+: maximum number of connections the pool may manage (default 5).
    # * +idle_timeout+: number of seconds that a connection will be kept
    #   unused in the pool before it is automatically disconnected (default
    #   300 seconds). Set this to zero to keep connections forever.
    # * +checkout_timeout+: number of seconds to wait for a connection to
    #   become available before giving up and raising a timeout error (default
    #   5 seconds).
    #
    #--
    # Synchronization policy:
    # * all public methods can be called outside +synchronize+
    # * access to these instance variables needs to be in +synchronize+:
    #   * @connections
    #   * @now_connecting
    # * private methods that require being called in a +synchronize+ blocks
    #   are now explicitly documented
    class ConnectionPool
      # Prior to 3.3.5, WeakKeyMap had a use after free bug
      # https://bugs.ruby-lang.org/issues/20688
      if ObjectSpace.const_defined?(:WeakKeyMap) && RUBY_VERSION >= "3.3.5"
        WeakThreadKeyMap = ObjectSpace::WeakKeyMap
      else
        class WeakThreadKeyMap # :nodoc:
          # FIXME: On 3.3 we could use ObjectSpace::WeakKeyMap
          # but it currently cause GC crashes: https://github.com/byroot/rails/pull/3
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
      include ConnectionAdapters::AbstractPool

      attr_accessor :automatic_reconnect, :checkout_timeout
      attr_reader :db_config, :size, :reaper, :pool_config, :async_executor, :role, :shard

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
        @size = db_config.pool

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

        @threads_blocking_new_connections = 0

        @available = ConnectionLeasingQueue.new self
        @pinned_connection = nil
        @pinned_connections_depth = 0

        @async_executor = build_async_executor

        @schema_cache = nil

        @reaper = Reaper.new(self, db_config.reaping_frequency)
        @reaper.run
      end

      def inspect # :nodoc:
        name_field = " name=#{db_config.name.inspect}" unless db_config.name == "primary"
        shard_field = " shard=#{@shard.inspect}" unless @shard == :default

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

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #lease_connection can be called any number of times; the connection is
      # held in a cache keyed by a thread.
      def lease_connection
        lease = connection_lease
        lease.sticky = true
        lease.connection ||= checkout
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
        @pinned_connection.verify! # eagerly validate the connection
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
        with_exclusively_acquired_all_connections(raise_on_acquisition_timeout) do
          synchronize do
            @connections.each do |conn|
              if conn.in_use?
                conn.steal!
                checkin conn
              end
              conn.disconnect!
            end
            @connections = []
            @leases.clear
            @available.clear
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
        synchronize do
          return if self.discarded?
          @connections.each do |conn|
            conn.discard!
          end
          @connections = @available = @leases = nil
        end
      end

      def discarded? # :nodoc:
        @connections.nil?
      end

      # Clears the cache which maps classes and re-connects connections that
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

      # Clears the cache which maps classes and re-connects connections that
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
              @pinned_connection.verify!

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

            conn._run_checkin_callbacks do
              conn.expire
            end

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
          # conn, the pool was at its max size (@connections.size == @size).
          # This would mean that any threads stuck waiting in the queue wouldn't
          # know they could checkout_new_connection, so let's do it for them.
          # Because condition-wait loop is encapsulated in the Queue class
          # (that in turn is oblivious to ConnectionPool implementation), threads
          # that are "stuck" there are helpless. They have no way of creating
          # new connections and are completely reliant on us feeding available
          # connections into the Queue.
          needs_new_connection = @available.any_waiting?
        end

        # This is intentionally done outside of the synchronized section as we
        # would like not to hold the main mutex while checking out new connections.
        # Thus there is some chance that needs_new_connection information is now
        # stale, we can live with that (bulk_make_new_connections will make
        # sure not to exceed the pool's @size limit).
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

        idle_connections = synchronize do
          return if self.discarded?
          @connections.select do |conn|
            !conn.in_use? && conn.seconds_idle >= minimum_idle
          end.each do |conn|
            conn.lease

            @available.delete conn
            @connections.delete conn
          end
        end

        idle_connections.each do |conn|
          conn.disconnect!
        end
      end

      # Disconnect all currently idle connections. Connections currently checked
      # out are unaffected.
      def flush!
        reap
        flush(-1)
      end

      def num_waiting_in_queue # :nodoc:
        @available.num_waiting
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

      private
        def connection_lease
          @leases[ActiveSupport::IsolatedExecutionState.context]
        end

        def build_async_executor
          case ActiveRecord.async_query_executor
          when :multi_thread_pool
            if @db_config.max_threads > 0
              Concurrent::ThreadPoolExecutor.new(
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

        #--
        # this is unfortunately not concurrent
        def bulk_make_new_connections(num_new_conns_needed)
          num_new_conns_needed.times do
            # try_to_checkout_new_connection will not exceed pool's @size limit
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
          with_new_connections_blocked do
            attempt_to_checkout_all_existing_connections(raise_on_acquisition_timeout)
            yield
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
          if conn = @available.poll || try_to_checkout_new_connection
            conn
          else
            reap
            # Retry after reaping, which may return an available connection,
            # remove an inactive connection, or both
            if conn = @available.poll || try_to_checkout_new_connection
              conn
            else
              @available.poll(checkout_timeout)
            end
          end
        rescue ConnectionTimeoutError => ex
          raise ex.set_pool(self)
        end

        #--
        # if owner_thread param is omitted, this must be called in synchronize block
        def remove_connection_from_thread_cache(conn, owner_thread = conn.owner)
          if owner_thread
            @leases[owner_thread].clear(conn)
          end
        end
        alias_method :release, :remove_connection_from_thread_cache

        # If the pool is not at a <tt>@size</tt> limit, establish new connection. Connecting
        # to the DB is done outside main synchronized section.
        #--
        # Implementation constraint: a newly established connection returned by this
        # method must be in the +.leased+ state.
        def try_to_checkout_new_connection
          # first in synchronized section check if establishing new conns is allowed
          # and increment @now_connecting, to prevent overstepping this pool's @size
          # constraint
          do_checkout = synchronize do
            if @threads_blocking_new_connections.zero? && (@connections.size + @now_connecting) < @size
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
                if conn
                  adopt_connection(conn)
                  # returned conn needs to be already leased
                  conn.lease
                end
                @now_connecting -= 1
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
          c._run_checkout_callbacks do
            c.clean!
          end
          c
        rescue Exception
          remove c
          c.disconnect!
          raise
        end
    end
  end
end

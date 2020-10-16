# frozen_string_literal: true

require "thread"
require "concurrent/map"
require "monitor"
require "weakref"

module ActiveRecord
  module ConnectionAdapters
    module AbstractPool # :nodoc:
      def get_schema_cache(connection)
        self.schema_cache ||= SchemaCache.new(connection)
        schema_cache.connection = connection
        schema_cache
      end

      def set_schema_cache(cache)
        self.schema_cache = cache
      end
    end

    class NullPool # :nodoc:
      include ConnectionAdapters::AbstractPool

      attr_accessor :schema_cache
    end

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
    # has checked in a connection.
    #
    # == Obtaining (checking out) a connection
    #
    # Connections can be obtained and used from a connection pool in several
    # ways:
    #
    # 1. Simply use {ActiveRecord::Base.connection}[rdoc-ref:ConnectionHandling.connection]
    #    as with Active Record 2.1 and
    #    earlier (pre-connection-pooling). Eventually, when you're done with
    #    the connection(s) and wish it to be returned to the pool, you call
    #    {ActiveRecord::Base.clear_active_connections!}[rdoc-ref:ConnectionAdapters::ConnectionHandler#clear_active_connections!].
    #    This will be the default behavior for Active Record when used in conjunction with
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
      # Threadsafe, fair, LIFO queue.  Meant to be used by ConnectionPool
      # with which it shares a Monitor.
      class Queue
        def initialize(lock = Monitor.new)
          @lock = lock
          @cond = @lock.new_cond
          @num_waiting = 0
          @queue = []
        end

        # Test if any threads are currently waiting on the queue.
        def any_waiting?
          synchronize do
            @num_waiting > 0
          end
        end

        # Returns the number of threads currently waiting on this
        # queue.
        def num_waiting
          synchronize do
            @num_waiting
          end
        end

        # Add +element+ to the queue.  Never blocks.
        def add(element)
          synchronize do
            @queue.push element
            @cond.signal
          end
        end

        # If +element+ is in the queue, remove and return it, or +nil+.
        def delete(element)
          synchronize do
            @queue.delete(element)
          end
        end

        # Remove all elements from the queue.
        def clear
          synchronize do
            @queue.clear
          end
        end

        # Remove the head of the queue.
        #
        # If +timeout+ is not given, remove and return the head of the
        # queue if the number of available elements is strictly
        # greater than the number of threads currently waiting (that
        # is, don't jump ahead in line).  Otherwise, return +nil+.
        #
        # If +timeout+ is given, block if there is no element
        # available, waiting up to +timeout+ seconds for an element to
        # become available.
        #
        # Raises:
        # - ActiveRecord::ConnectionTimeoutError if +timeout+ is given and no element
        # becomes available within +timeout+ seconds,
        def poll(timeout = nil)
          synchronize { internal_poll(timeout) }
        end

        private
          def internal_poll(timeout)
            no_wait_poll || (timeout && wait_poll(timeout))
          end

          def synchronize(&block)
            @lock.synchronize(&block)
          end

          # Test if the queue currently contains any elements.
          def any?
            !@queue.empty?
          end

          # A thread can remove an element from the queue without
          # waiting if and only if the number of currently available
          # connections is strictly greater than the number of waiting
          # threads.
          def can_remove_no_wait?
            @queue.size > @num_waiting
          end

          # Removes and returns the head of the queue if possible, or +nil+.
          def remove
            @queue.pop
          end

          # Remove and return the head of the queue if the number of
          # available elements is strictly greater than the number of
          # threads currently waiting.  Otherwise, return +nil+.
          def no_wait_poll
            remove if can_remove_no_wait?
          end

          # Waits on the queue up to +timeout+ seconds, then removes and
          # returns the head of the queue.
          def wait_poll(timeout)
            @num_waiting += 1

            t0 = Concurrent.monotonic_time
            elapsed = 0
            loop do
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                @cond.wait(timeout - elapsed)
              end

              return remove if any?

              elapsed = Concurrent.monotonic_time - t0
              if elapsed >= timeout
                msg = "could not obtain a connection from the pool within %0.3f seconds (waited %0.3f seconds); all pooled connections were in use" %
                  [timeout, elapsed]
                raise ConnectionTimeoutError, msg
              end
            end
          ensure
            @num_waiting -= 1
          end
      end

      # Adds the ability to turn a basic fair FIFO queue into one
      # biased to some thread.
      module BiasableQueue # :nodoc:
        class BiasedConditionVariable # :nodoc:
          # semantics of condition variables guarantee that +broadcast+, +broadcast_on_biased+,
          # +signal+ and +wait+ methods are only called while holding a lock
          def initialize(lock, other_cond, preferred_thread)
            @real_cond = lock.new_cond
            @other_cond = other_cond
            @preferred_thread = preferred_thread
            @num_waiting_on_real_cond = 0
          end

          def broadcast
            broadcast_on_biased
            @other_cond.broadcast
          end

          def broadcast_on_biased
            @num_waiting_on_real_cond = 0
            @real_cond.broadcast
          end

          def signal
            if @num_waiting_on_real_cond > 0
              @num_waiting_on_real_cond -= 1
              @real_cond
            else
              @other_cond
            end.signal
          end

          def wait(timeout)
            if Thread.current == @preferred_thread
              @num_waiting_on_real_cond += 1
              @real_cond
            else
              @other_cond
            end.wait(timeout)
          end
        end

        def with_a_bias_for(thread)
          previous_cond = nil
          new_cond      = nil
          synchronize do
            previous_cond = @cond
            @cond = new_cond = BiasedConditionVariable.new(@lock, @cond, thread)
          end
          yield
        ensure
          synchronize do
            @cond = previous_cond if previous_cond
            new_cond.broadcast_on_biased if new_cond # wake up any remaining sleepers
          end
        end
      end

      # Connections must be leased while holding the main pool mutex. This is
      # an internal subclass that also +.leases+ returned connections while
      # still in queue's critical section (queue synchronizes with the same
      # <tt>@lock</tt> as the main pool) so that a returned connection is already
      # leased and there is no need to re-enter synchronized block.
      class ConnectionLeasingQueue < Queue # :nodoc:
        include BiasableQueue

        private
          def internal_poll(timeout)
            conn = super
            conn.lease if conn
            conn
          end
      end

      # Every +frequency+ seconds, the reaper will call +reap+ and +flush+ on
      # +pool+. A reaper instantiated with a zero frequency will never reap
      # the connection pool.
      #
      # Configure the frequency by setting +reaping_frequency+ in your database
      # yaml file (default 60 seconds).
      class Reaper
        attr_reader :pool, :frequency

        def initialize(pool, frequency)
          @pool      = pool
          @frequency = frequency
        end

        @mutex = Mutex.new
        @pools = {}
        @threads = {}

        class << self
          def register_pool(pool, frequency) # :nodoc:
            @mutex.synchronize do
              unless @threads[frequency]&.alive?
                @threads[frequency] = spawn_thread(frequency)
              end
              @pools[frequency] ||= []
              @pools[frequency] << WeakRef.new(pool)
            end
          end

          private
            def spawn_thread(frequency)
              Thread.new(frequency) do |t|
                # Advise multi-threaded app servers to ignore this thread for
                # the purposes of fork safety warnings
                Thread.current[:fork_safe] = true
                running = true
                while running
                  sleep t
                  @mutex.synchronize do
                    @pools[frequency].select! do |pool|
                      pool.weakref_alive? && !pool.discarded?
                    end

                    @pools[frequency].each do |p|
                      p.reap
                      p.flush
                    rescue WeakRef::RefError
                    end

                    if @pools[frequency].empty?
                      @pools.delete(frequency)
                      @threads.delete(frequency)
                      running = false
                    end
                  end
                end
              end
            end
        end

        def run
          return unless frequency && frequency > 0
          self.class.register_pool(pool, frequency)
        end
      end

      include MonitorMixin
      include QueryCache::ConnectionPoolConfiguration
      include ConnectionAdapters::AbstractPool

      attr_accessor :automatic_reconnect, :checkout_timeout
      attr_reader :db_config, :size, :reaper, :pool_config

      delegate :schema_cache, :schema_cache=, to: :pool_config

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

        @checkout_timeout = db_config.checkout_timeout
        @idle_timeout = db_config.idle_timeout
        @size = db_config.pool

        # This variable tracks the cache of threads mapped to reserved connections, with the
        # sole purpose of speeding up the +connection+ method. It is not the authoritative
        # registry of which thread owns which connection. Connection ownership is tracked by
        # the +connection.owner+ attr on each +connection+ instance.
        # The invariant works like this: if there is mapping of <tt>thread => conn</tt>,
        # then that +thread+ does indeed own that +conn+. However, an absence of a such
        # mapping does not mean that the +thread+ doesn't own the said connection. In
        # that case +conn.owner+ attr should be consulted.
        # Access and modification of <tt>@thread_cached_conns</tt> does not require
        # synchronization.
        @thread_cached_conns = Concurrent::Map.new(initial_capacity: @size)

        @connections         = []
        @automatic_reconnect = true

        # Connection pool allows for concurrent (outside the main +synchronize+ section)
        # establishment of new connections. This variable tracks the number of threads
        # currently in the process of independently establishing connections to the DB.
        @now_connecting = 0

        @threads_blocking_new_connections = 0

        @available = ConnectionLeasingQueue.new self

        @lock_thread = false

        @reaper = Reaper.new(self, db_config.reaping_frequency)
        @reaper.run
      end

      def lock_thread=(lock_thread)
        if lock_thread
          @lock_thread = Thread.current
        else
          @lock_thread = nil
        end
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #connection can be called any number of times; the connection is
      # held in a cache keyed by a thread.
      def connection
        @thread_cached_conns[connection_cache_key(current_thread)] ||= checkout
      end

      # Returns true if there is an open connection being used for the current thread.
      #
      # This method only works for connections that have been obtained through
      # #connection or #with_connection methods. Connections obtained through
      # #checkout will not be detected by #active_connection?
      def active_connection?
        @thread_cached_conns[connection_cache_key(current_thread)]
      end

      # Signal that the thread is finished with the current connection.
      # #release_connection releases the connection-thread association
      # and returns the connection to the pool.
      #
      # This method only works for connections that have been obtained through
      # #connection or #with_connection methods, connections obtained through
      # #checkout will not be automatically released.
      def release_connection(owner_thread = Thread.current)
        if conn = @thread_cached_conns.delete(connection_cache_key(owner_thread))
          checkin conn
        end
      end

      # If a connection obtained through #connection or #with_connection methods
      # already exists yield it to the block. If no such connection
      # exists checkout a connection, yield it to the block, and checkin the
      # connection when finished.
      def with_connection
        unless conn = @thread_cached_conns[connection_cache_key(Thread.current)]
          conn = connection
          fresh_connection = true
        end
        yield conn
      ensure
        release_connection if fresh_connection
      end

      # Returns true if a connection has already been opened.
      def connected?
        synchronize { @connections.any? }
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
          @connections = @available = @thread_cached_conns = nil
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
        checkout_and_verify(acquire_connection(checkout_timeout))
      end

      # Check-in a database connection back into the pool, indicating that you
      # no longer need this connection.
      #
      # +conn+: an AbstractAdapter object, which was obtained by earlier by
      # calling #checkout on this pool.
      def checkin(conn)
        conn.lock.synchronize do
          synchronize do
            remove_connection_from_thread_cache conn

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

      # Return connection pool's usage statistic
      # Example:
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

      private
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

        #--
        # From the discussion on GitHub:
        #  https://github.com/rails/rails/pull/14938#commitcomment-6601951
        # This hook-in method allows for easier monkey-patching fixes needed by
        # JRuby users that use Fibers.
        def connection_cache_key(thread)
          thread
        end

        def current_thread
          @lock_thread || Thread.current
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
            # account for our own connections
            @connections.select { |conn| conn.owner == Thread.current }
          end

          newly_checked_out = []
          timeout_time      = Concurrent.monotonic_time + (@checkout_timeout * 2)

          @available.with_a_bias_for(Thread.current) do
            loop do
              synchronize do
                return if collected_conns.size == @connections.size && @now_connecting == 0
                remaining_timeout = timeout_time - Concurrent.monotonic_time
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
            unless conn.owner == Thread.current
              thread_report << "#{conn} is owned by #{conn.owner}"
            end
          end

          msg << " (#{thread_report.join(', ')})" if thread_report.any?

          raise ExclusiveConnectionTimeoutError, msg
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
            @available.poll(checkout_timeout)
          end
        end

        #--
        # if owner_thread param is omitted, this must be called in synchronize block
        def remove_connection_from_thread_cache(conn, owner_thread = conn.owner)
          @thread_cached_conns.delete_pair(connection_cache_key(owner_thread), conn)
        end
        alias_method :release, :remove_connection_from_thread_cache

        def new_connection
          Base.public_send(db_config.adapter_method, db_config.configuration_hash).tap do |conn|
            conn.check_version
          end
        end

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
        end

        def checkout_new_connection
          raise ConnectionNotEstablished unless @automatic_reconnect
          new_connection
        end

        def checkout_and_verify(c)
          c._run_checkout_callbacks do
            c.verify!
          end
          c
        rescue
          remove c
          c.disconnect!
          raise
        end
    end

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
    # Book, ScaryBook and GoodBook will all use the same connection pool to
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
      FINALIZER = lambda { |_| ActiveSupport::ForkTracker.check! }
      private_constant :FINALIZER

      def initialize
        # These caches are keyed by pool_config.connection_specification_name (PoolConfig#connection_specification_name).
        @owner_to_pool_manager = Concurrent::Map.new(initial_capacity: 2)

        # Backup finalizer: if the forked child skipped Kernel#fork the early discard has not occurred
        ObjectSpace.define_finalizer self, FINALIZER
      end

      def prevent_writes # :nodoc:
        Thread.current[:prevent_writes]
      end

      def prevent_writes=(prevent_writes) # :nodoc:
        Thread.current[:prevent_writes] = prevent_writes
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
      def while_preventing_writes(enabled = true)
        original, self.prevent_writes = self.prevent_writes, enabled
        yield
      ensure
        self.prevent_writes = original
      end

      def connection_pool_names # :nodoc:
        owner_to_pool_manager.keys
      end

      def connection_pool_list
        owner_to_pool_manager.values.flat_map { |m| m.pool_configs.map(&:pool) }
      end
      alias :connection_pools :connection_pool_list

      def establish_connection(config, owner_name: Base.name, shard: Base.default_shard)
        owner_name = config.to_s if config.is_a?(Symbol)

        pool_config = resolve_pool_config(config, owner_name)
        db_config = pool_config.db_config

        # Protects the connection named `ActiveRecord::Base` from being removed
        # if the user calls `establish_connection :primary`.
        if owner_to_pool_manager.key?(pool_config.connection_specification_name)
          remove_connection_pool(pool_config.connection_specification_name, shard: shard)
        end

        message_bus = ActiveSupport::Notifications.instrumenter
        payload = {}
        if pool_config
          payload[:spec_name] = pool_config.connection_specification_name
          payload[:config] = db_config.configuration_hash
        end

        owner_to_pool_manager[pool_config.connection_specification_name] ||= PoolManager.new
        pool_manager = get_pool_manager(pool_config.connection_specification_name)
        pool_manager.set_pool_config(shard, pool_config)

        message_bus.instrument("!connection.active_record", payload) do
          pool_config.pool
        end
      end

      # Returns true if there are any active connections among the connection
      # pools that the ConnectionHandler is managing.
      def active_connections?
        connection_pool_list.any?(&:active_connection?)
      end

      # Returns any connections in use by the current thread back to the pool,
      # and also returns connections to the pool cached by threads that are no
      # longer alive.
      def clear_active_connections!
        connection_pool_list.each(&:release_connection)
      end

      # Clears the cache which maps classes.
      #
      # See ConnectionPool#clear_reloadable_connections! for details.
      def clear_reloadable_connections!
        connection_pool_list.each(&:clear_reloadable_connections!)
      end

      def clear_all_connections!
        connection_pool_list.each(&:disconnect!)
      end

      # Disconnects all currently idle connections.
      #
      # See ConnectionPool#flush! for details.
      def flush_idle_connections!
        connection_pool_list.each(&:flush!)
      end

      # Locate the connection of the nearest super class. This can be an
      # active or defined connection: if it is the latter, it will be
      # opened and set as the active connection for the class it was defined
      # for (not necessarily the current class).
      def retrieve_connection(spec_name, shard: ActiveRecord::Base.default_shard) # :nodoc:
        pool = retrieve_connection_pool(spec_name, shard: shard)

        unless pool
          if shard != ActiveRecord::Base.default_shard
            message = "No connection pool for '#{spec_name}' found for the '#{shard}' shard."
          elsif ActiveRecord::Base.connection_handler != ActiveRecord::Base.default_connection_handler
            message = "No connection pool for '#{spec_name}' found for the '#{ActiveRecord::Base.current_role}' role."
          else
            message = "No connection pool for '#{spec_name}' found."
          end

          raise ConnectionNotEstablished, message
        end

        pool.connection
      end

      # Returns true if a connection that's accessible to this class has
      # already been opened.
      def connected?(spec_name, shard: ActiveRecord::Base.default_shard)
        pool = retrieve_connection_pool(spec_name, shard: shard)
        pool && pool.connected?
      end

      # Remove the connection for this class. This will close the active
      # connection and the defined connection (if they exist). The result
      # can be used as an argument for #establish_connection, for easily
      # re-establishing the connection.
      def remove_connection(owner, shard: ActiveRecord::Base.default_shard)
        remove_connection_pool(owner, shard: shard)&.configuration_hash
      end
      deprecate remove_connection: "Use #remove_connection_pool, which now returns a DatabaseConfig object instead of a Hash"

      def remove_connection_pool(owner, shard: ActiveRecord::Base.default_shard)
        if pool_manager = get_pool_manager(owner)
          pool_config = pool_manager.remove_pool_config(shard)

          if pool_config
            pool_config.disconnect!
            pool_config.db_config
          end
        end
      end

      # Retrieving the connection pool happens a lot, so we cache it in @owner_to_pool_manager.
      # This makes retrieving the connection pool O(1) once the process is warm.
      # When a connection is established or removed, we invalidate the cache.
      def retrieve_connection_pool(owner, shard: ActiveRecord::Base.default_shard)
        pool_config = get_pool_manager(owner)&.get_pool_config(shard)
        pool_config&.pool
      end

      private
        attr_reader :owner_to_pool_manager

        # Returns the pool manager for an owner.
        #
        # Using `"primary"` to look up the pool manager for `ActiveRecord::Base` is
        # deprecated in favor of looking it up by `"ActiveRecord::Base"`.
        #
        # During the deprecation period, if `"primary"` is passed, the pool manager
        # for `ActiveRecord::Base` will still be returned.
        def get_pool_manager(owner)
          return owner_to_pool_manager[owner] if owner_to_pool_manager.key?(owner)

          if owner == "primary"
            ActiveSupport::Deprecation.warn("Using `\"primary\"` as a `connection_specification_name` is deprecated and will be removed in Rails 6.2.0. Please use `ActiveRecord::Base`.")
            owner_to_pool_manager[Base.name]
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
        def resolve_pool_config(config, owner_name)
          db_config = Base.configurations.resolve(config)

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless db_config.adapter

          # Require the adapter itself and give useful feedback about
          #   1. Missing adapter gems and
          #   2. Adapter gems' missing dependencies.
          path_to_adapter = "active_record/connection_adapters/#{db_config.adapter}_adapter"
          begin
            require path_to_adapter
          rescue LoadError => e
            # We couldn't require the adapter itself. Raise an exception that
            # points out config typos and missing gems.
            if e.path == path_to_adapter
              # We can assume that a non-builtin adapter was specified, so it's
              # either misspelled or missing from Gemfile.
              raise LoadError, "Could not load the '#{db_config.adapter}' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

              # Bubbled up from the adapter require. Prefix the exception message
              # with some guidance about how to address it and reraise.
            else
              raise LoadError, "Error loading the '#{db_config.adapter}' Active Record adapter. Missing a gem it depends on? #{e.message}", e.backtrace
            end
          end

          unless ActiveRecord::Base.respond_to?(db_config.adapter_method)
            raise AdapterNotFound, "database configuration specifies nonexistent #{db_config.adapter} adapter"
          end

          ConnectionAdapters::PoolConfig.new(owner_name, db_config)
        end
    end
  end
end

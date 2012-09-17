require 'thread'
require 'monitor'
require 'set'
require 'active_support/core_ext/module/deprecation'

module ActiveRecord
  # Raised when a connection could not be obtained within the connection
  # acquisition timeout period.
  class ConnectionTimeoutError < ConnectionNotEstablished
  end

  module ConnectionAdapters
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
    # 1. Simply use ActiveRecord::Base.connection as with Active Record 2.1 and
    #    earlier (pre-connection-pooling). Eventually, when you're done with
    #    the connection(s) and wish it to be returned to the pool, you call
    #    ActiveRecord::Base.clear_active_connections!. This will be the
    #    default behavior for Active Record when used in conjunction with
    #    Action Pack's request handling cycle.
    # 2. Manually check out a connection from the pool with
    #    ActiveRecord::Base.connection_pool.checkout. You are responsible for
    #    returning this connection to the pool when finished by calling
    #    ActiveRecord::Base.connection_pool.checkin(connection).
    # 3. Use ActiveRecord::Base.connection_pool.with_connection(&block), which
    #    obtains a connection, yields it as the sole argument to the block,
    #    and returns it to the pool after the block completes.
    #
    # Connections in the pool are actually AbstractAdapter objects (or objects
    # compatible with AbstractAdapter's interface).
    #
    # == Options
    #
    # There are two connection-pooling-related options that you can add to
    # your database connection configuration:
    #
    # * +pool+: number indicating size of connection pool (default 5)
    # * +wait_timeout+: number of seconds to block and wait for a connection
    #   before giving up and raising a timeout error (default 5 seconds).
    class ConnectionPool

      # Threadsafe, fair, FIFO queue.  Meant to be used by ConnectionPool
      # with which it shares a Monitor.  But could be a generic Queue.
      #
      # The Queue in stdlib's 'thread' could replace this class except
      # stdlib's doesn't support waiting with a timeout.
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

        # Return the number of threads currently waiting on this
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

        # If +element+ is in the queue, remove and return it, or nil.
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
        # If +timeout+ is not given, remove and return the head the
        # queue if the number of available elements is strictly
        # greater than the number of threads currently waiting (that
        # is, don't jump ahead in line).  Otherwise, return nil.
        #
        # If +timeout+ is given, block if it there is no element
        # available, waiting up to +timeout+ seconds for an element to
        # become available.
        #
        # Raises:
        # - ConnectionTimeoutError if +timeout+ is given and no element
        # becomes available after +timeout+ seconds,
        def poll(timeout = nil)
          synchronize do
            if timeout
              no_wait_poll || wait_poll(timeout)
            else
              no_wait_poll
            end
          end
        end

        private

        def synchronize(&block)
          @lock.synchronize(&block)
        end

        # Test if the queue currently contains any elements.
        def any?
          !@queue.empty?
        end

        # A thread can remove an element from the queue without
        # waiting if an only if the number of currently available
        # connections is strictly greater than the number of waiting
        # threads.
        def can_remove_no_wait?
          @queue.size > @num_waiting
        end

        # Removes and returns the head of the queue if possible, or nil.
        def remove
          @queue.shift
        end

        # Remove and return the head the queue if the number of
        # available elements is strictly greater than the number of
        # threads currently waiting.  Otherwise, return nil.
        def no_wait_poll
          remove if can_remove_no_wait?
        end

        # Waits on the queue up to +timeout+ seconds, then removes and
        # returns the head of the queue.
        def wait_poll(timeout)
          @num_waiting += 1

          t0 = Time.now
          elapsed = 0
          loop do
            @cond.wait(timeout - elapsed)

            return remove if any?

            elapsed = Time.now - t0

            if elapsed >= timeout
              msg = 'could not obtain a database connection within %0.3f seconds (waited %0.3f seconds)' %
                [timeout, elapsed]
              raise ConnectionTimeoutError, msg
            end
          end
        ensure
          @num_waiting -= 1
        end
      end

      include MonitorMixin

      attr_accessor :automatic_reconnect
      attr_reader :spec, :connections, :size

      # Creates a new ConnectionPool object. +spec+ is a ConnectionSpecification
      # object which describes database connection information (e.g. adapter,
      # host name, username, password, etc), as well as the maximum size for
      # this ConnectionPool.
      #
      # The default ConnectionPool maximum size is 5.
      def initialize(spec)
        super()

        @spec = spec

        # The cache of reserved connections mapped to threads
        @reserved_connections = {}

        @timeout = spec.config[:wait_timeout] || 5

        # default max pool size to 5
        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @connections         = []
        @automatic_reconnect = true

        @available = Queue.new self
      end

      # Hack for tests to be able to add connections.  Do not call outside of tests
      def insert_connection_for_test!(c) #:nodoc:
        synchronize do
          @connections << c
          @available.add c
        end
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #connection can be called any number of times; the connection is
      # held in a hash keyed by the thread id.
      def connection
        synchronize do
          @reserved_connections[current_connection_id] ||= checkout
        end
      end

      # Is there an open connection that is being used for the current thread?
      def active_connection?
        synchronize do
          @reserved_connections.fetch(current_connection_id) {
            return false
          }.in_use?
        end
      end

      # Signal that the thread is finished with the current connection.
      # #release_connection releases the connection-thread association
      # and returns the connection to the pool.
      def release_connection(with_id = current_connection_id)
        conn = @reserved_connections.delete(with_id)
        checkin conn if conn
      end

      # If a connection already exists yield it to the block. If no connection
      # exists checkout a connection, yield it to the block, and checkin the
      # connection when finished.
      def with_connection
        connection_id = current_connection_id
        fresh_connection = true unless active_connection?
        yield connection
      ensure
        release_connection(connection_id) if fresh_connection
      end

      # Returns true if a connection has already been opened.
      def connected?
        synchronize { @connections.any? }
      end

      # Disconnects all connections in the pool, and clears the pool.
      def disconnect!
        synchronize do
          @reserved_connections = {}
          @connections.each do |conn|
            checkin conn
            conn.disconnect!
          end
          @connections = []
          @available.clear
        end
      end

      # Clears the cache which maps classes.
      def clear_reloadable_connections!
        synchronize do
          @reserved_connections = {}
          @connections.each do |conn|
            checkin conn
            conn.disconnect! if conn.requires_reloading?
          end

          @connections.delete_if do |conn|
            conn.requires_reloading?
          end
          @available.clear
          @connections.each do |conn|
            @available.add conn
          end
          
        end
      end

      # Verify active connections and remove and disconnect connections
      # associated with stale threads.
      def verify_active_connections! #:nodoc:
        synchronize do
          clear_stale_cached_connections!
          @connections.each do |connection|
            connection.verify!
          end
        end
      end

      def columns
        with_connection do |c|
          c.schema_cache.columns
        end
      end
      deprecate :columns

      def columns_hash
        with_connection do |c|
          c.schema_cache.columns_hash
        end
      end
      deprecate :columns_hash

      def primary_keys
        with_connection do |c|
          c.schema_cache.primary_keys
        end
      end
      deprecate :primary_keys

      def clear_cache!
        with_connection do |c|
          c.schema_cache.clear!
        end
      end
      deprecate :clear_cache!

      # Return any checked-out connections back to the pool by threads that
      # are no longer alive.
      def clear_stale_cached_connections!
        keys = @reserved_connections.keys - Thread.list.find_all { |t|
          t.alive?
        }.map { |thread| thread.object_id }
        keys.each do |key|
          conn = @reserved_connections[key]
          ActiveSupport::Deprecation.warn(<<-eowarn) if conn.in_use?
Database connections will not be closed automatically, please close your
database connection at the end of the thread by calling `close` on your
connection.  For example: ActiveRecord::Base.connection.close
          eowarn
          checkin conn
          @reserved_connections.delete(key)
        end
      end

      # Check-out a database connection from the pool, indicating that you want
      # to use it. You should call #checkin when you no longer need this.
      #
      # This is done by either returning and leasing existing connection, or by
      # creating a new connection and leasing it.
      #
      # If all connections are leased and the pool is at capacity (meaning the
      # number of currently leased connections is greater than or equal to the
      # size limit set), an ActiveRecord::PoolFullError exception will be raised.
      #
      # Returns: an AbstractAdapter object.
      #
      # Raises:
      # - PoolFullError: no connection can be obtained from the pool.
      def checkout
        synchronize do
          conn = acquire_connection
          conn.lease
          checkout_and_verify(conn)
        end
      end

      # Check-in a database connection back into the pool, indicating that you
      # no longer need this connection.
      #
      # +conn+: an AbstractAdapter object, which was obtained by earlier by
      # calling +checkout+ on this pool.
      def checkin(conn)
        synchronize do
          conn.run_callbacks :checkin do
            conn.expire
          end

          release conn

          @available.add conn
        end
      end

      # Acquire a connection by one of 1) immediately removing one
      # from the queue of available connections, 2) creating a new
      # connection if the pool is not at capacity, 3) waiting on the
      # queue for a connection to become available (first calling
      # clear_stale_cached_connections! to clean up leaked connections,
      # this cleanup will prob be going away in Rails4).
      #
      # Raises:
      # - ConnectionTimeoutError if a connection could not be acquired
      def acquire_connection
        if conn = @available.poll
          conn
        elsif @connections.size < @size
          checkout_new_connection
        else
          # this conditional clear_stale will go away in Rails 4, when we don't
          # clean up after leaked connections automatically anymore. Right now,
          # clean up after we've returned from a 'wait' if it looks like it's
          # needed before trying to wait for a connection.
          synchronize do
            if(active_connections.size >= @connections.size)
              clear_stale_cached_connections!
            end
          end

          @available.poll(@timeout)
        end
      end

      private

      def release(conn)
        synchronize do
          thread_id = nil

          if @reserved_connections[current_connection_id] == conn
            thread_id = current_connection_id
          else
            thread_id = @reserved_connections.keys.find { |k|
              @reserved_connections[k] == conn
            }
          end

          @reserved_connections.delete thread_id if thread_id
        end
      end

      def new_connection
        ActiveRecord::Base.send(spec.adapter_method, spec.config)
      end

      def current_connection_id #:nodoc:
        ActiveRecord::Base.connection_id ||= Thread.current.object_id
      end

      def checkout_new_connection
        raise ConnectionNotEstablished unless @automatic_reconnect

        c = new_connection
        c.pool = self
        @connections << c
        c
      end

      def checkout_and_verify(c)
        c.run_callbacks :checkout do
          c.verify!
        end
        c
      end

      def active_connections
        @connections.find_all { |c| c.in_use? }
      end
    end

    # ConnectionHandler is a collection of ConnectionPool objects. It is used
    # for keeping separate connection pools for Active Record models that connect
    # to different databases.
    #
    # For example, suppose that you have 5 models, with the following hierarchy:
    #
    #  |
    #  +-- Book
    #  |    |
    #  |    +-- ScaryBook
    #  |    +-- GoodBook
    #  +-- Author
    #  +-- BankAccount
    #
    # Suppose that Book is to connect to a separate database (i.e. one other
    # than the default database). Then Book, ScaryBook and GoodBook will all use
    # the same connection pool. Likewise, Author and BankAccount will use the
    # same connection pool. However, the connection pool used by Author/BankAccount
    # is not the same as the one used by Book/ScaryBook/GoodBook.
    #
    # Normally there is only a single ConnectionHandler instance, accessible via
    # ActiveRecord::Base.connection_handler. Active Record models use this to
    # determine that connection pool that they should use.
    class ConnectionHandler
      attr_reader :connection_pools

      def initialize(pools = {})
        @connection_pools = pools
        @class_to_pool    = {}
      end

      def establish_connection(name, spec)
        @connection_pools[spec] ||= ConnectionAdapters::ConnectionPool.new(spec)
        @class_to_pool[name] = @connection_pools[spec]
      end

      # Returns true if there are any active connections among the connection
      # pools that the ConnectionHandler is managing.
      def active_connections?
        connection_pools.values.any? { |pool| pool.active_connection? }
      end

      # Returns any connections in use by the current thread back to the pool.
      def clear_active_connections!
        @connection_pools.each_value {|pool| pool.release_connection }
      end

      # Clears the cache which maps classes.
      def clear_reloadable_connections!
        @connection_pools.each_value {|pool| pool.clear_reloadable_connections! }
      end

      def clear_all_connections!
        @connection_pools.each_value {|pool| pool.disconnect! }
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        @connection_pools.each_value {|pool| pool.verify_active_connections! }
      end

      # Locate the connection of the nearest super class. This can be an
      # active or defined connection: if it is the latter, it will be
      # opened and set as the active connection for the class it was defined
      # for (not necessarily the current class).
      def retrieve_connection(klass) #:nodoc:
        pool = retrieve_connection_pool(klass)
        (pool && pool.connection) or raise ConnectionNotEstablished
      end

      # Returns true if a connection that's accessible to this class has
      # already been opened.
      def connected?(klass)
        conn = retrieve_connection_pool(klass)
        conn && conn.connected?
      end

      # Remove the connection for this class. This will close the active
      # connection and the defined connection (if they exist). The result
      # can be used as an argument for establish_connection, for easily
      # re-establishing the connection.
      def remove_connection(klass)
        pool = @class_to_pool.delete(klass.name)
        return nil unless pool

        @connection_pools.delete pool.spec
        pool.automatic_reconnect = false
        pool.disconnect!
        pool.spec.config
      end

      def retrieve_connection_pool(klass)
        pool = @class_to_pool[klass.name]
        return pool if pool
        return nil if ActiveRecord::Base == klass
        retrieve_connection_pool klass.superclass
      end
    end

    class ConnectionManagement
      class Proxy # :nodoc:
        attr_reader :body, :testing

        def initialize(body, testing = false)
          @body    = body
          @testing = testing
        end

        def method_missing(method_sym, *arguments, &block)
          @body.send(method_sym, *arguments, &block)
        end

        def respond_to?(method_sym, include_private = false)
          super || @body.respond_to?(method_sym)
        end

        def each(&block)
          body.each(&block)
        end

        def close
          body.close if body.respond_to?(:close)

          # Don't return connection (and perform implicit rollback) if
          # this request is a part of integration test
          ActiveRecord::Base.clear_active_connections! unless testing
        end
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        testing = env.key?('rack.test')

        status, headers, body = @app.call(env)

        [status, headers, Proxy.new(body, testing)]
      rescue
        ActiveRecord::Base.clear_active_connections! unless testing
        raise
      end
    end
  end
end

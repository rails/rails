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
    # * +checkout _timeout+: number of seconds to block and wait for a 
    #   connection before giving up and raising a timeout error 
    #   (default 5 seconds). ('wait_timeout' supported for backwards
    #   compatibility, but conflicts with key used for different purpose
    #   by mysql2 adapter). 
    class ConnectionPool
      include MonitorMixin

      attr_accessor :automatic_reconnect
      attr_reader :spec, :connections

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

        @queue = new_cond
        # 'wait_timeout', the backward-compatible key, conflicts with spec key 
        # used by mysql2 for something entirely different, checkout_timeout
        # preferred to avoid conflict and allow independent values. 
        @timeout = spec.config[:checkout_timeout] || spec.config[:wait_timeout] || 5

        # default max pool size to 5
        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @connections         = []
        @automatic_reconnect = true
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
        conn = synchronize { @reserved_connections.delete(with_id) }
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
      # This is done by either returning an existing connection, or by creating
      # a new connection. If the maximum number of connections for this pool has
      # already been reached, but the pool is empty (i.e. they're all being used),
      # then this method will wait until a thread has checked in a connection.
      # The wait time is bounded however: if no connection can be checked out
      # within the timeout specified for this pool, then a ConnectionTimeoutError
      # exception will be raised.
      #
      # Returns: an AbstractAdapter object.
      #
      # Raises:
      # - ConnectionTimeoutError: no connection can be obtained from the pool
      #   within the timeout period.
      def checkout
        synchronize do
          waited_time = 0

          loop do
            conn = @connections.find { |c| c.lease }

            unless conn
              if @connections.size < @size
                conn = checkout_new_connection
                conn.lease
              end
            end

            if conn
              checkout_and_verify conn
              return conn
            end

            if waited_time >= @timeout
              raise ConnectionTimeoutError, "could not obtain a database connection#{" within #{@timeout} seconds" if @timeout} (waited #{waited_time} seconds). The max pool size is currently #{@size}; consider increasing it."
            end

            # Sometimes our wait can end because a connection is available,
            # but another thread can snatch it up first. If timeout hasn't
            # passed but no connection is avail, looks like that happened --
            # loop and wait again, for the time remaining on our timeout. 
            before_wait = Time.now
            @queue.wait( [@timeout - waited_time, 0].max )
            waited_time += (Time.now - before_wait)

            # Will go away in Rails 4, when we don't clean up
            # after leaked connections automatically anymore. Right now, clean
            # up after we've returned from a 'wait' if it looks like it's
            # needed, then loop and try again. 
            if(active_connections.size >= @connections.size)
              clear_stale_cached_connections!
            end
          end
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
            @queue.signal
          end

          release conn
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

require 'thread'
require 'monitor'
require 'set'
require 'active_support/core_ext/module/synchronization'

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
      attr_accessor :automatic_reconnect
      attr_reader :spec, :connections
      attr_reader :columns, :columns_hash, :primary_keys, :tables
      attr_reader :column_defaults

      # Creates a new ConnectionPool object. +spec+ is a ConnectionSpecification
      # object which describes database connection information (e.g. adapter,
      # host name, username, password, etc), as well as the maximum size for
      # this ConnectionPool.
      #
      # The default ConnectionPool maximum size is 5.
      def initialize(spec)
        @spec = spec

        # The cache of reserved connections mapped to threads
        @reserved_connections = {}

        # The mutex used to synchronize pool access
        @connection_mutex = Monitor.new
        @queue = @connection_mutex.new_cond
        @timeout = spec.config[:wait_timeout] || 5

        # default max pool size to 5
        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @connections         = []
        @checked_out         = []
        @automatic_reconnect = true
        @tables              = {}
        @visitor             = nil

        @columns     = Hash.new do |h, table_name|
          h[table_name] = with_connection do |conn|

            # Fetch a list of columns
            conn.columns(table_name, "#{table_name} Columns").tap do |columns|

              # set primary key information
              columns.each do |column|
                column.primary = column.name == primary_keys[table_name]
              end
            end
          end
        end

        @columns_hash = Hash.new do |h, table_name|
          h[table_name] = Hash[columns[table_name].map { |col|
            [col.name, col]
          }]
        end

        @column_defaults = Hash.new do |h, table_name|
          h[table_name] = Hash[columns[table_name].map { |col|
            [col.name, col.default]
          }]
        end

        @primary_keys = Hash.new do |h, table_name|
          h[table_name] = with_connection do |conn|
            table_exists?(table_name) ? conn.primary_key(table_name) : 'id'
          end
        end
      end

      # A cached lookup for table existence.
      def table_exists?(name)
        return true if @tables.key? name

        with_connection do |conn|
          conn.tables.each { |table| @tables[table] = true }
          @tables[name] = true if !@tables.key?(name) && conn.table_exists?(name)
        end

        @tables.key? name
      end

      # Clears out internal caches:
      #
      #   * columns
      #   * columns_hash
      #   * tables
      def clear_cache!
        @columns.clear
        @columns_hash.clear
        @column_defaults.clear
        @tables.clear
      end

      # Clear out internal caches for table with +table_name+.
      def clear_table_cache!(table_name)
        @columns.delete table_name
        @columns_hash.delete table_name
        @column_defaults.delete table_name
        @primary_keys.delete table_name
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #connection can be called any number of times; the connection is
      # held in a hash keyed by the thread id.
      def connection
        @reserved_connections[current_connection_id] ||= checkout
      end

      # Check to see if there is an active connection in this connection
      # pool.
      def active_connection?
        @reserved_connections.key? current_connection_id
      end

      # Signal that the thread is finished with the current connection.
      # #release_connection releases the connection-thread association
      # and returns the connection to the pool.
      def release_connection(with_id = current_connection_id)
        conn = @reserved_connections.delete(with_id)
        checkin conn if conn
      end

      # If a connection already exists yield it to the block.  If no connection
      # exists checkout a connection, yield it to the block, and checkin the
      # connection when finished.
      def with_connection
        connection_id = current_connection_id
        fresh_connection = true unless @reserved_connections[connection_id]
        yield connection
      ensure
        release_connection(connection_id) if fresh_connection
      end

      # Returns true if a connection has already been opened.
      def connected?
        !@connections.empty?
      end

      # Disconnects all connections in the pool, and clears the pool.
      def disconnect!
        @reserved_connections.each do |name,conn|
          checkin conn
        end
        @reserved_connections = {}
        @connections.each do |conn|
          conn.disconnect!
        end
        @connections = []
      end

      # Clears the cache which maps classes.
      def clear_reloadable_connections!
        @reserved_connections.each do |name, conn|
          checkin conn
        end
        @reserved_connections = {}
        @connections.each do |conn|
          conn.disconnect! if conn.requires_reloading?
        end
        @connections.delete_if do |conn|
          conn.requires_reloading?
        end
      end

      # Verify active connections and remove and disconnect connections
      # associated with stale threads.
      def verify_active_connections! #:nodoc:
        clear_stale_cached_connections!
        @connections.each do |connection|
          connection.verify!
        end
      end

      # Return any checked-out connections back to the pool by threads that
      # are no longer alive.
      def clear_stale_cached_connections!
        keys = @reserved_connections.keys - Thread.list.find_all { |t|
          t.alive?
        }.map { |thread| thread.object_id }
        keys.each do |key|
          checkin @reserved_connections[key]
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
        # Checkout an available connection
        @connection_mutex.synchronize do
          loop do
            conn = if @checked_out.size < @connections.size
                     checkout_existing_connection
                   elsif @connections.size < @size
                     checkout_new_connection
                   end
            return conn if conn

            @queue.wait(@timeout)

            if(@checked_out.size < @connections.size)
              next
            else
              clear_stale_cached_connections!
              if @size == @checked_out.size
                raise ConnectionTimeoutError, "could not obtain a database connection#{" within #{@timeout} seconds" if @timeout}.  The max pool size is currently #{@size}; consider increasing it."
              end
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
        @connection_mutex.synchronize do
          conn.run_callbacks :checkin do
            @checked_out.delete conn
            @queue.signal
          end
        end
      end

      synchronize :clear_reloadable_connections!, :verify_active_connections!,
        :connected?, :disconnect!, :with => :@connection_mutex

      private

      def new_connection
        connection = ActiveRecord::Base.send(spec.adapter_method, spec.config)

        # TODO: This is a bit icky, and in the long term we may want to change the method
        #       signature for connections. Also, if we switch to have one visitor per
        #       connection (and therefore per thread), we can get rid of the thread-local
        #       variable in Arel::Visitors::ToSql.
        @visitor ||= connection.class.visitor_for(self)
        connection.visitor = @visitor

        connection
      end

      def current_connection_id #:nodoc:
        ActiveRecord::Base.connection_id ||= Thread.current.object_id
      end

      def checkout_new_connection
        raise ConnectionNotEstablished unless @automatic_reconnect

        c = new_connection
        @connections << c
        checkout_and_verify(c)
      end

      def checkout_existing_connection
        c = (@connections - @checked_out).first
        checkout_and_verify(c)
      end

      def checkout_and_verify(c)
        c.run_callbacks :checkout do
          c.verify!
          @checked_out << c
        end
        c
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
      end

      def establish_connection(name, spec)
        @connection_pools[name] = ConnectionAdapters::ConnectionPool.new(spec)
      end

      # Returns true if there are any active connections among the connection
      # pools that the ConnectionHandler is managing.
      def active_connections?
        connection_pools.values.any? { |pool| pool.active_connection? }
      end

      # Returns any connections in use by the current thread back to the pool,
      # and also returns connections to the pool cached by threads that are no
      # longer alive.
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
        pool = @connection_pools.delete(klass.name)
        return nil unless pool

        pool.automatic_reconnect = false
        pool.disconnect!
        pool.spec.config
      end

      def retrieve_connection_pool(klass)
        pool = @connection_pools[klass.name]
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

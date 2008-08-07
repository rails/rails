require 'monitor'
require 'set'

module ActiveRecord
  module ConnectionAdapters
    # Connection pool base class and ActiveRecord database connections.
    class ConnectionPool
      # Factory method for connection pools.
      # Determines pool type to use based on contents of connection specification.
      # FIXME: specification configuration TBD.
      def self.create(spec)
        ConnectionPerThread.new(spec)
      end

      delegate :verification_timeout, :to => "::ActiveRecord::Base"
      attr_reader :spec

      def initialize(spec)
        @spec = spec
        # The cache of reserved connections mapped to threads
        @reserved_connections = {}
        # The mutex used to synchronize pool access
        @connection_mutex = Monitor.new
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #connection can be called any number of times; the connection is
      # held in a hash keyed by the thread id.
      def connection
        if conn = @reserved_connections[active_connection_name]
          conn.verify!(verification_timeout)
          conn
        else
          @reserved_connections[active_connection_name] = checkout
        end
      end

      # Signal that the thread is finished with the current connection.
      # #release_thread_connection releases the connection-thread association
      # and returns the connection to the pool.
      def release_thread_connection
        conn = @reserved_connections.delete(active_connection_name)
        checkin conn if conn
      end

      # Reserve a connection, and yield it to a block. Ensure the connection is
      # checked back in when finished.
      def with_connection
        conn = checkout
        yield conn
      ensure
        checkin conn
      end

      # Returns true if a connection has already been opened.
      def connected?
        !connections.empty?
      end

      # Disconnect all connections in the pool.
      def disconnect!
        @reserved_connections.each do |name,conn|
          checkin conn
        end
        connections.each do |conn|
          conn.disconnect!
        end
        @reserved_connections = {}
      end

      # Clears the cache which maps classes
      def clear_reloadable_connections!
        @reserved_connections.each do |name, conn|
          checkin conn
        end
        @reserved_connections = {}
        connections.each do |conn|
          if conn.requires_reloading?
            conn.disconnect!
            remove_connection conn
          end
        end
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        remove_stale_cached_threads!(@reserved_connections) do |name, conn|
          checkin conn
        end
        connections.each do |connection|
          connection.verify!(verification_timeout)
        end
      end

      # Check-out a database connection from the pool.
      def checkout
        raise NotImplementedError, "checkout is an abstract method"
      end

      # Check-in a database connection back into the pool.
      def checkin(connection)
        raise NotImplementedError, "checkin is an abstract method"
      end

      def remove_connection(conn)
        raise NotImplementedError, "remove_connection is an abstract method"
      end
      private :remove_connection

      # Array containing all connections (reserved or available) in the pool.
      def connections
        raise NotImplementedError, "connections is an abstract method"
      end
      private :connections

      synchronize :connection, :release_thread_connection, :checkout, :checkin,
        :clear_reloadable_connections!, :verify_active_connections!,
        :connected?, :disconnect!, :with => :@connection_mutex

      private
      def active_connection_name #:nodoc:
        Thread.current.object_id
      end

      # Remove stale threads from the cache.
      def remove_stale_cached_threads!(cache, &block)
        keys = Set.new(cache.keys)

        Thread.list.each do |thread|
          keys.delete(thread.object_id) if thread.alive?
        end
        keys.each do |key|
          next unless cache.has_key?(key)
          block.call(key, cache[key])
          cache.delete(key)
        end
      end
    end

    class ConnectionPerThread < ConnectionPool
      def active_connection
        @reserved_connections[active_connection_name]
      end

      def active_connections; @reserved_connections; end

      def checkout
        new_connection
      end

      def checkin(conn)
        conn.disconnect!
      end

      private
      # Set the connection for the class.
      def new_connection
        config = spec.config.reverse_merge(:allow_concurrency => ActiveRecord::Base.allow_concurrency)
        ActiveRecord::Base.send(spec.adapter_method, config)
      end

      def connections
        @reserved_connections.values
      end

      def remove_connection(conn)
        @reserved_connections.delete_if {|k,v| v == conn}
      end
    end

    module ConnectionHandlerMethods
      def initialize(pools = {})
        @connection_pools = pools
      end

      def connection_pools
        @connection_pools ||= {}
      end

      def establish_connection(name, spec)
        @connection_pools[name] = ConnectionAdapters::ConnectionPool.create(spec)
      end

      # for internal use only and for testing;
      # only works with ConnectionPerThread pool class
      def active_connections #:nodoc:
        @connection_pools.inject({}) do |hash,kv|
          hash[kv.first] = kv.last.active_connection
          hash.delete(kv.first) unless hash[kv.first]
          hash
        end
      end

      # Clears the cache which maps classes to connections.
      def clear_active_connections!
        @connection_pools.each_value {|pool| pool.release_thread_connection }
      end

      # Clears the cache which maps classes
      def clear_reloadable_connections!
        @connection_pools.each_value {|pool| pool.clear_reloadable_connections! }
      end

      def clear_all_connections!
        @connection_pools.each_value {|pool| pool.disconnect! }
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        @connection_pools.each_value {|pool| pool.verify_active_connections!}
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
        retrieve_connection_pool(klass).connected?
      end

      # Remove the connection for this class. This will close the active
      # connection and the defined connection (if they exist). The result
      # can be used as an argument for establish_connection, for easily
      # re-establishing the connection.
      def remove_connection(klass)
        pool = @connection_pools[klass.name]
        @connection_pools.delete_if { |key, value| value == pool }
        pool.disconnect! if pool
        pool.spec.config if pool
      end

      private
        def retrieve_connection_pool(klass)
          loop do
            pool = @connection_pools[klass.name]
            return pool if pool
            return nil if ActiveRecord::Base == klass
            klass = klass.superclass
          end
        end
    end

    # This connection handler is not thread-safe, as it does not protect access
    # to the underlying connection pools.
    class SingleThreadConnectionHandler
      include ConnectionHandlerMethods
    end

    # This connection handler is thread-safe. Each access or modification of a thread
    # pool is synchronized by an internal monitor.
    class MultipleThreadConnectionHandler
      attr_reader :connection_pools_lock
      include ConnectionHandlerMethods

      def initialize(pools = {})
        super
        @connection_pools_lock = Monitor.new
      end

      # Apply monitor to all public methods that access the pool.
      synchronize :establish_connection, :retrieve_connection,
        :connected?, :remove_connection, :active_connections,
        :clear_active_connections!, :clear_reloadable_connections!,
        :clear_all_connections!, :verify_active_connections!,
        :with => :connection_pools_lock
    end
  end
end
require 'monitor'
require 'set'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      delegate :verification_timeout, :to => "::ActiveRecord::Base"
      attr_reader :active_connections, :spec

      def initialize(spec)
        # The thread id -> adapter cache.
        @active_connections = {}

        # The ConnectionSpecification for this pool
        @spec = spec

        # The mutex used to synchronize pool access
        @connection_mutex = Monitor.new
      end

      def active_connection_name #:nodoc:
        Thread.current.object_id
      end

      def active_connection
        active_connections[active_connection_name]
      end

      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do database work unrelated
      # to any of the specific Active Records.
      def connection
        if conn = active_connections[active_connection_name]
          conn
        else
          # retrieve_connection sets the cache key.
          conn = retrieve_connection
          active_connections[active_connection_name] = conn
        end
      end

      # Clears the cache which maps classes to connections.
      def clear_active_connections!
        clear_entries!(@active_connections, [active_connection_name]) do |name, conn|
          conn.disconnect!
        end
      end

      # Clears the cache which maps classes
      def clear_reloadable_connections!
        @active_connections.each do |name, conn|
          if conn.requires_reloading?
            conn.disconnect!
            @active_connections.delete(name)
          end
        end
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        remove_stale_cached_threads!(@active_connections) do |name, conn|
          conn.disconnect!
        end
        active_connections.each_value do |connection|
          connection.verify!(verification_timeout)
        end
      end

      def retrieve_connection #:nodoc:
        # Name is nil if establish_connection hasn't been called for
        # some class along the inheritance chain up to AR::Base yet.
        name = active_connection_name
        if conn = active_connections[name]
          # Verify the connection.
          conn.verify!(verification_timeout)
        else
          self.set_connection spec
          conn = active_connections[name]
        end

        conn or raise ConnectionNotEstablished
      end

      # Returns true if a connection that's accessible to this class has already been opened.
      def connected?
        active_connections[active_connection_name] ? true : false
      end

      # Disconnect all connections in the pool.
      def disconnect!
        clear_cache!(@active_connections) do |name, conn|
          conn.disconnect!
        end
      end

      # Set the connection for the class.
      def set_connection(spec) #:nodoc:
        if spec.kind_of?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
          active_connections[active_connection_name] = spec
        elsif spec.kind_of?(ActiveRecord::Base::ConnectionSpecification)
          config = spec.config.reverse_merge(:allow_concurrency => ActiveRecord::Base.allow_concurrency)
          self.set_connection ActiveRecord::Base.send(spec.adapter_method, config)
        else
          raise ConnectionNotEstablished
        end
      end

      synchronize :active_connection, :connection, :clear_active_connections!,
        :clear_reloadable_connections!, :verify_active_connections!, :retrieve_connection,
        :connected?, :disconnect!, :set_connection, :with => :@connection_mutex

      private
        def clear_cache!(cache, &block)
          cache.each(&block) if block_given?
          cache.clear
        end

        # Remove stale threads from the cache.
        def remove_stale_cached_threads!(cache, &block)
          stale = Set.new(cache.keys)

          Thread.list.each do |thread|
            stale.delete(thread.object_id) if thread.alive?
          end
          clear_entries!(cache, stale, &block)
        end

        def clear_entries!(cache, keys, &block)
          keys.each do |key|
            next unless cache.has_key?(key)
            block.call(key, cache[key])
            cache.delete(key)
          end
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
        @connection_pools[name] = ConnectionAdapters::ConnectionPool.new(spec)
      end

      # for internal use only and for testing
      def active_connections #:nodoc:
        @connection_pools.inject({}) do |hash,kv|
          hash[kv.first] = kv.last.active_connection
          hash.delete(kv.first) unless hash[kv.first]
          hash
        end
      end

      # Clears the cache which maps classes to connections.
      def clear_active_connections!
        @connection_pools.each_value {|pool| pool.clear_active_connections! }
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

      # Returns true if a connection that's accessible to this class has already been opened.
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
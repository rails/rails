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
          self.connection = spec
          conn = active_connections[name]
        end

        conn or raise ConnectionNotEstablished
      end

      # Returns true if a connection that's accessible to this class has already been opened.
      def connected?
        active_connections[active_connection_name] ? true : false
      end

      def disconnect!
        clear_cache!(@active_connections) do |name, conn|
          conn.disconnect!
        end
      end

      # Set the connection for the class.
      def connection=(spec) #:nodoc:
        if spec.kind_of?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
          active_connections[active_connection_name] = spec
        elsif spec.kind_of?(ActiveRecord::Base::ConnectionSpecification)
          self.connection = ActiveRecord::Base.send(spec.adapter_method, spec.config)
        else
          raise ConnectionNotEstablished
        end
      end

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
  end
end
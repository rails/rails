require 'set'

module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    # Check for activity after at least +verification_timeout+ seconds.
    # Defaults to 0 (always check.)
    cattr_accessor :verification_timeout, :instance_writer => false
    @@verification_timeout = 0

    # The class -> [adapter_method, config] map
    @@defined_connections = {}

    # The class -> thread id -> adapter cache. (class -> adapter if not allow_concurrency)
    @@active_connections = {}

    class << self
      # Retrieve the connection cache.
      def thread_safe_active_connections #:nodoc:
        @@active_connections[Thread.current.object_id] ||= {}
      end
     
      def single_threaded_active_connections #:nodoc:
        @@active_connections
      end
     
      # pick up the right active_connection method from @@allow_concurrency
      if @@allow_concurrency
        alias_method :active_connections, :thread_safe_active_connections
      else
        alias_method :active_connections, :single_threaded_active_connections
      end
     
      # set concurrency support flag (not thread safe, like most of the methods in this file)
      def allow_concurrency=(threaded) #:nodoc:
        logger.debug "allow_concurrency=#{threaded}" if logger
        return if @@allow_concurrency == threaded
        clear_all_cached_connections!
        @@allow_concurrency = threaded
        method_prefix = threaded ? "thread_safe" : "single_threaded"
        sing = (class << self; self; end)
        [:active_connections, :scoped_methods].each do |method|
          sing.send(:alias_method, method, "#{method_prefix}_#{method}")
        end
        log_connections if logger
      end
      
      def active_connection_name #:nodoc:
        @active_connection_name ||=
           if active_connections[name] || @@defined_connections[name]
             name
           elsif self == ActiveRecord::Base
             nil
           else
             superclass.active_connection_name
           end
      end

      def clear_active_connection_name #:nodoc:
        @active_connection_name = nil
        subclasses.each { |klass| klass.clear_active_connection_name }
      end

      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do database work unrelated
      # to any of the specific Active Records.
      def connection
        if @active_connection_name && (conn = active_connections[@active_connection_name])
          conn
        else
          # retrieve_connection sets the cache key.
          conn = retrieve_connection
          active_connections[@active_connection_name] = conn
        end
      end

      # Clears the cache which maps classes to connections.
      def clear_active_connections!
        clear_cache!(@@active_connections) do |name, conn|
          conn.disconnect!
        end
      end
      
      # Clears the cache which maps classes 
      def clear_reloadable_connections!
        if @@allow_concurrency
          # With concurrent connections @@active_connections is
          # a hash keyed by thread id.
          @@active_connections.each do |thread_id, conns|
            conns.each do |name, conn|
              if conn.requires_reloading?
                conn.disconnect!
                @@active_connections[thread_id].delete(name)
              end
            end
          end
        else
          @@active_connections.each do |name, conn|
            if conn.requires_reloading?
              conn.disconnect!
              @@active_connections.delete(name)
            end
          end
        end
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        if @@allow_concurrency
          remove_stale_cached_threads!(@@active_connections) do |name, conn|
            conn.disconnect!
          end
        end
        
        active_connections.each_value do |connection|
          connection.verify!(@@verification_timeout)
        end
      end

      private
        def clear_cache!(cache, thread_id = nil, &block)
          if cache
            if @@allow_concurrency
              thread_id ||= Thread.current.object_id
              thread_cache, cache = cache, cache[thread_id]
              return unless cache
            end

            cache.each(&block) if block_given?
            cache.clear
          end
        ensure
          if thread_cache && @@allow_concurrency
            thread_cache.delete(thread_id)
          end
        end

        # Remove stale threads from the cache.
        def remove_stale_cached_threads!(cache, &block)
          stale = Set.new(cache.keys)

          Thread.list.each do |thread|
            stale.delete(thread.object_id) if thread.alive?
          end

          stale.each do |thread_id|
            clear_cache!(cache, thread_id, &block)
          end
        end
        
        def clear_all_cached_connections!
          if @@allow_concurrency
            @@active_connections.each_value do |connection_hash_for_thread|
              connection_hash_for_thread.each_value {|conn| conn.disconnect! }
              connection_hash_for_thread.clear
            end
          else
            @@active_connections.each_value {|conn| conn.disconnect! }
          end
          @@active_connections.clear          
        end
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work that isn't
    # easily done without going straight to SQL.
    def connection
      self.class.connection
    end

    # Establishes the connection to the database. Accepts a hash as input where
    # the :adapter key must be specified with the name of a database adapter (in lower-case)
    # example for regular databases (MySQL, Postgresql, etc):
    #
    #   ActiveRecord::Base.establish_connection(
    #     :adapter  => "mysql",
    #     :host     => "localhost",
    #     :username => "myuser",
    #     :password => "mypass",
    #     :database => "somedatabase"
    #   )
    #
    # Example for SQLite database:
    #
    #   ActiveRecord::Base.establish_connection(
    #     :adapter => "sqlite",
    #     :database  => "path/to/dbfile"
    #   )
    #
    # Also accepts keys as strings (for parsing from yaml for example):
    #   ActiveRecord::Base.establish_connection(
    #     "adapter" => "sqlite",
    #     "database"  => "path/to/dbfile"
    #   )
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
    # may be returned on an error.
    def self.establish_connection(spec = nil)
      case spec
        when nil
          raise AdapterNotSpecified unless defined? RAILS_ENV
          establish_connection(RAILS_ENV)
        when ConnectionSpecification
          clear_active_connection_name
          @active_connection_name = name
          @@defined_connections[name] = spec
        when Symbol, String
          if configuration = configurations[spec.to_s]
            establish_connection(configuration)
          else
            raise AdapterNotSpecified, "#{spec} database is not configured"
          end
        else
          spec = spec.symbolize_keys
          unless spec.key?(:adapter) then raise AdapterNotSpecified, "database configuration does not specify adapter" end

          begin
            require 'rubygems'
            gem "activerecord-#{spec[:adapter]}-adapter"
            require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          rescue LoadError
            begin
              require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
            rescue LoadError
              raise "Please install the #{spec[:adapter]} adapter: `gem install activerecord-#{spec[:adapter]}-adapter` (#{$!})"
            end
          end

          adapter_method = "#{spec[:adapter]}_connection"
          if !respond_to?(adapter_method)
            raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter"
          end

          remove_connection
          establish_connection(ConnectionSpecification.new(spec, adapter_method))
      end
    end

    # Locate the connection of the nearest super class. This can be an
    # active or defined connection: if it is the latter, it will be
    # opened and set as the active connection for the class it was defined
    # for (not necessarily the current class).
    def self.retrieve_connection #:nodoc:
      # Name is nil if establish_connection hasn't been called for
      # some class along the inheritance chain up to AR::Base yet.
      if name = active_connection_name
        if conn = active_connections[name]
          # Verify the connection.
          conn.verify!(@@verification_timeout)
        elsif spec = @@defined_connections[name]
          # Activate this connection specification.
          klass = name.constantize
          klass.connection = spec
          conn = active_connections[name]
        end
      end

      conn or raise ConnectionNotEstablished
    end

    # Returns true if a connection that's accessible to this class has already been opened.
    def self.connected?
      active_connections[active_connection_name] ? true : false
    end

    # Remove the connection for this class. This will close the active
    # connection and the defined connection (if they exist). The result
    # can be used as an argument for establish_connection, for easily
    # re-establishing the connection.
    def self.remove_connection(klass=self)
      spec = @@defined_connections[klass.name]
      konn = active_connections[klass.name]
      @@defined_connections.delete_if { |key, value| value == spec }
      active_connections.delete_if { |key, value| value == konn }
      konn.disconnect! if konn
      spec.config if spec
    end

    # Set the connection for the class.
    def self.connection=(spec) #:nodoc:
      if spec.kind_of?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
        active_connections[name] = spec
      elsif spec.kind_of?(ConnectionSpecification)
        config = spec.config.reverse_merge(:allow_concurrency => @@allow_concurrency)
        self.connection = self.send(spec.adapter_method, config)
      elsif spec.nil?
        raise ConnectionNotEstablished
      else
        establish_connection spec
      end
    end

    # connection state logging
    def self.log_connections #:nodoc:
      if logger
        logger.info "Defined connections: #{@@defined_connections.inspect}"
        logger.info "Active connections: #{active_connections.inspect}"
        logger.info "Active connection name: #{@active_connection_name}"
      end
    end
  end
end

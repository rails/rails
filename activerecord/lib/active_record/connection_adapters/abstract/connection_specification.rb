module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    # Check connections for active? after +@@connection_cache_timeout+ seconds
    # defaults to 5 minutes
    cattr_accessor :connection_cache_timeout
    @@connection_cache_timeout = 300
    
    # The class -> [adapter_method, config] map
    @@defined_connections = {}

    # The class -> thread id -> adapter cache. (class -> adapter if not allow_concurrency)
    @@connection_cache = {}

    # retrieve the connection cache
    def self.connection_cache
      if @@allow_concurrency
        @@connection_cache[Thread.current.object_id] ||= {}
      else
        @@connection_cache
      end
    end
    
    @connection_cache_key = nil
    def self.connection_cache_key
      @connection_cache_key ||=
         if active_connections[name] || @@defined_connections[name]
           name
         elsif self == ActiveRecord::Base
           nil
         else
           superclass.connection_cache_key
         end
    end
    
    def self.clear_connection_cache_key
      @connection_cache_key = nil
      subclasses.each{|klass| klass.clear_connection_cache_key }
    end
    
    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work unrelated
    # to any of the specific Active Records.
    def self.connection
      if (cache_key = @connection_cache_key) && (conn = connection_cache[cache_key])
        conn
      else
        conn = retrieve_connection # this will set @connection_cache_key
        connection_cache[@connection_cache_key] = conn
      end
    end

    # Clears the cache which maps classes to connections.
    def self.clear_connection_cache!
      if @@allow_concurrency
        @@connection_cache.delete(Thread.current.object_id)
      else
        @@connection_cache = {}
      end
    end
   
    # Verify connection cache.
    def self.verify_connection_cache!
      timeout = @@connection_cache_timeout
      connection_cache.each_value { |connection| connection.verify!(timeout) }
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
          clear_connection_cache_key
          @connection_cache_key = name 
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
          adapter_method = "#{spec[:adapter]}_connection"
          unless respond_to?(adapter_method) then raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter" end
          remove_connection
          establish_connection(ConnectionSpecification.new(spec, adapter_method))
      end
    end

    def self.active_connections #:nodoc:
      if @@allow_concurrency
        Thread.current['active_connections'] ||= {}
      else
        @@active_connections ||= {}
      end
    end

    # Locate the connection of the nearest super class. This can be an
    # active or defined connections: if it is the latter, it will be
    # opened and set as the active connection for the class it was defined
    # for (not necessarily the current class).
    def self.retrieve_connection #:nodoc:
      cache_key = connection_cache_key
      # cache_key is nil if establish_connection hasn't been called for
      # some class along the inheritance chain up to AR::Base yet
      raise ConnectionNotEstablished unless cache_key
      if conn = active_connections[cache_key]
        # Verify the connection.
        conn.verify!(@@connection_cache_timeout)
        return conn
      elsif conn = @@defined_connections[cache_key]
        # Activate this connection specification.
        klass = cache_key.constantize
        klass.connection = conn
        return active_connections[cache_key]
      else
        raise ConnectionNotEstablished
      end
    end

    # Returns true if a connection that's accessible to this class have already been opened.
    def self.connected?
      active_connections[connection_cache_key] ? true : false
    end

    # Remove the connection for this class. This will close the active
    # connection and the defined connection (if they exist). The result
    # can be used as argument for establish_connection, for easy
    # re-establishing of the connection.
    def self.remove_connection(klass=self)
      spec = @@defined_connections[klass.name]
      konn = active_connections[klass.name]
      @@defined_connections.delete_if { |key, value| value == spec }
      connection_cache.delete_if { |key, value| value == konn }
      active_connections.delete_if { |key, value| value == konn }
      konn.disconnect! if konn
      spec.config if spec
    end

    # Set the connection for the class.
    def self.connection=(spec)
      if spec.kind_of?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
        active_connections[name] = spec
      elsif spec.kind_of?(ConnectionSpecification)
        self.connection = self.send(spec.adapter_method, spec.config)
      elsif spec.nil?
        raise ConnectionNotEstablished
      else
        establish_connection spec
      end
    end
      
    # connection state logging
    def self.log_connections
      if logger
        logger.info "Defined connections: #{@@defined_connections.inspect}"
        logger.info "Active connections: #{active_connections.inspect}"
        logger.info "Connection cache: #{connection_cache.inspect}"
        logger.info "Connection cache key: #{@connection_cache_key}"
      end
    end
  end
end

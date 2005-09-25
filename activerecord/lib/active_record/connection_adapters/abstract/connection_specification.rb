module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    # The class -> [adapter_method, config] map
    @@defined_connections = {}

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
    #     :dbfile  => "path/to/dbfile"
    #   )
    #
    # Also accepts keys as strings (for parsing from yaml for example):
    #   ActiveRecord::Base.establish_connection(
    #     "adapter" => "sqlite",
    #     "dbfile"  => "path/to/dbfile"
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
          @@defined_connections[self] = spec
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
      if threaded_connections
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
      klass = self
      ar_super = ActiveRecord::Base.superclass
      until klass == ar_super
        if conn = active_connections[klass]
          return conn
        elsif conn = @@defined_connections[klass]
          klass.connection = conn
          return self.connection
        end
        klass = klass.superclass
      end
      raise ConnectionNotEstablished
    end

    # Returns true if a connection that's accessible to this class have already been opened.
    def self.connected?
      klass = self
      until klass == ActiveRecord::Base.superclass
        if active_connections[klass]
          return true
        else
          klass = klass.superclass
        end
      end
      return false
    end

    # Remove the connection for this class. This will close the active
    # connection and the defined connection (if they exist). The result
    # can be used as argument for establish_connection, for easy
    # re-establishing of the connection.
    def self.remove_connection(klass=self)
      conn = @@defined_connections[klass]
      @@defined_connections.delete(klass)
      active_connections[klass] = nil
      conn.config if conn
    end

    # Set the connection for the class.
    def self.connection=(spec)
      raise ConnectionNotEstablished unless spec
      conn = self.send(spec.adapter_method, spec.config)
      active_connections[self] = conn
    end

    # Converts all strings in a hash to symbols.
    def self.symbolize_strings_in_hash(hash) #:nodoc:
      hash.symbolize_keys
    end
  end
end
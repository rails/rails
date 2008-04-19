require 'monitor'

module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    class NullMonitor
      def synchronize
        yield
      end
    end

    cattr_accessor :connection_pools_lock, :instance_writer => false
    @@connection_pools_lock = NullMonitor.new

    # Check for activity after at least +verification_timeout+ seconds.
    # Defaults to 0 (always check.)
    cattr_accessor :verification_timeout, :instance_writer => false
    @@verification_timeout = 0

    # The class -> connection pool map
    @@connection_pools = {}

    class << self
      # Turning on allow_concurrency basically switches a null mutex for a real one, so that
      # multi-threaded access of the connection pools hash is synchronized.
      def allow_concurrency=(flag)
        if @@allow_concurrency != flag
          if flag
            self.connection_pools_lock = Monitor.new
          else
            self.connection_pools_lock = NullMonitor.new
          end
        end
      end

      # for internal use only and for testing
      def active_connections #:nodoc:
        @@connection_pools.inject({}) do |hash,kv|
          hash[kv.first] = kv.last.active_connection
          hash.delete(kv.first) unless hash[kv.first]
          hash
        end
      end

      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do database work unrelated
      # to any of the specific Active Records.
      def connection
        retrieve_connection
      end

      # Clears the cache which maps classes to connections.
      def clear_active_connections!
        @@connection_pools.each_value {|pool| pool.clear_active_connections! }
      end
      
      # Clears the cache which maps classes
      def clear_reloadable_connections!
        @@connection_pools.each_value {|pool| pool.clear_reloadable_connections! }
      end

      def clear_all_connections!
        clear_cache!(@@connection_pools) {|name, pool| pool.disconnect! }
      end

      # Verify active connections.
      def verify_active_connections! #:nodoc:
        @@connection_pools.each_value {|pool| pool.verify_active_connections!}
      end

      synchronize :active_connections, :clear_active_connections!, :clear_reloadable_connections!,
        :clear_all_connections!, :verify_active_connections!, :with => :connection_pools_lock

      private
        def clear_cache!(cache, &block)
          cache.each(&block) if block_given?
          cache.clear
        end
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work that isn't
    # easily done without going straight to SQL.
    def connection
      self.class.connection
    end

    # Establishes the connection to the database. Accepts a hash as input where
    # the <tt>:adapter</tt> key must be specified with the name of a database adapter (in lower-case)
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
    # Also accepts keys as strings (for parsing from YAML for example):
    #
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
          connection_pools_lock.synchronize do
            @@connection_pools[name] = ConnectionAdapters::ConnectionPool.new(spec)
          end
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
      pool = retrieve_connection_pool
      (pool && pool.connection) or raise ConnectionNotEstablished
    end

    def self.retrieve_connection_pool
      pool = @@connection_pools[name]
      return pool if pool
      return nil if ActiveRecord::Base == self
      superclass.retrieve_connection_pool
    end

    # Returns true if a connection that's accessible to this class has already been opened.
    def self.connected?
      retrieve_connection_pool.connected?
    end

    # Remove the connection for this class. This will close the active
    # connection and the defined connection (if they exist). The result
    # can be used as an argument for establish_connection, for easily
    # re-establishing the connection.
    def self.remove_connection(klass=self)
      pool = @@connection_pools[klass.name]
      @@connection_pools.delete_if { |key, value| value == pool }
      pool.disconnect! if pool
      pool.spec.config if pool
    end

    class << self
      synchronize :retrieve_connection, :retrieve_connection_pool, :connected?,
        :remove_connection, :with => :connection_pools_lock
    end
  end
end

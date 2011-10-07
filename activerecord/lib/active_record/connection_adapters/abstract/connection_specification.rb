module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    ##
    # :singleton-method:
    # The connection handler
    class_attribute :connection_handler, :instance_writer => false
    self.connection_handler = ConnectionAdapters::ConnectionHandler.new

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
          raise AdapterNotSpecified unless defined?(Rails.env)
          establish_connection(Rails.env)
        when ConnectionSpecification
          self.connection_handler.establish_connection(name, spec)
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
            require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          rescue LoadError => e
            raise "Please install the #{spec[:adapter]} adapter: `gem install activerecord-#{spec[:adapter]}-adapter` (#{e})"
          end

          adapter_method = "#{spec[:adapter]}_connection"
          unless respond_to?(adapter_method)
            raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter"
          end

          remove_connection
          establish_connection(ConnectionSpecification.new(spec, adapter_method))
      end
    end

    class << self
      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do database work unrelated
      # to any of the specific Active Records.
      def connection
        retrieve_connection
      end

      def connection_id
        Thread.current['ActiveRecord::Base.connection_id']
      end

      def connection_id=(connection_id)
        Thread.current['ActiveRecord::Base.connection_id'] = connection_id
      end

      # Returns the configuration of the associated connection as a hash:
      #
      #  ActiveRecord::Base.connection_config
      #  # => {:pool=>5, :timeout=>5000, :database=>"db/development.sqlite3", :adapter=>"sqlite3"}
      #
      # Please use only for reading.
      def connection_config
        connection_pool.spec.config
      end

      def connection_pool
        connection_handler.retrieve_connection_pool(self) or raise ConnectionNotEstablished
      end

      def retrieve_connection
        connection_handler.retrieve_connection(self)
      end

      # Returns true if Active Record is connected.
      def connected?
        connection_handler.connected?(self)
      end

      def remove_connection(klass = self)
        connection_handler.remove_connection(klass)
      end

      def clear_active_connections!
        connection_handler.clear_active_connections!
      end

      delegate :clear_reloadable_connections!,
        :clear_all_connections!,:verify_active_connections!, :to => :connection_handler
    end
  end
end

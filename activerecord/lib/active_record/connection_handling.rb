module ActiveRecord
  module ConnectionHandling
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
    # Or a URL:
    #
    #   ActiveRecord::Base.establish_connection(
    #     "postgres://myuser:mypass@localhost/somedatabase"
    #   )
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
    # may be returned on an error.
    def establish_connection(spec = ENV["DATABASE_URL"])
      resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new spec, configurations
      spec = resolver.spec

      unless respond_to?(spec.adapter_method)
        raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
      end

      remove_connection
      connection_handler.establish_connection self, spec
    end

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

    def clear_cache! # :nodoc:
      connection.schema_cache.clear!
    end

    delegate :clear_active_connections!, :clear_reloadable_connections!,
      :clear_all_connections!, :to => :connection_handler
  end
end

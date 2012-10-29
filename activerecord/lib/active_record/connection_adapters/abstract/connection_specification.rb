require 'uri'

module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end

      ##
      # Builds a ConnectionSpecification from user input
      class Resolver # :nodoc:
        attr_reader :config, :klass, :configurations

        def initialize(config, configurations)
          @config         = config
          @configurations = configurations
        end

        def spec
          case config
          when nil
            raise AdapterNotSpecified unless defined?(Rails.env)
            resolve_string_connection Rails.env
          when Symbol, String
            resolve_string_connection config.to_s
          when Hash
            resolve_hash_connection config
          end
        end

        private
        def resolve_string_connection(spec) # :nodoc:
          hash = configurations.fetch(spec) do |k|
            connection_url_to_hash(k)
          end

          raise(AdapterNotSpecified, "#{spec} database is not configured") unless hash

          resolve_hash_connection hash
        end

        def resolve_hash_connection(spec) # :nodoc:
          spec = spec.symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          begin
            require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          rescue LoadError => e
            raise LoadError, "Please install the #{spec[:adapter]} adapter: `gem install activerecord-#{spec[:adapter]}-adapter` (#{e.message})", e.backtrace
          end

          adapter_method = "#{spec[:adapter]}_connection"

          ConnectionSpecification.new(spec, adapter_method)
        end

        def connection_url_to_hash(url) # :nodoc:
          config = URI.parse url
          adapter = config.scheme
          adapter = "postgresql" if adapter == "postgres"
          spec = { :adapter  => adapter,
                   :username => config.user,
                   :password => config.password,
                   :port     => config.port,
                   :database => config.path.sub(%r{^/},""),
                   :host     => config.host }
          spec.reject!{ |_,value| value.blank? }
          spec.map { |key,value| spec[key] = URI.unescape(value) if value.is_a?(String) }
          if config.query
            options = Hash[config.query.split("&").map{ |pair| pair.split("=") }].symbolize_keys
            spec.merge!(options)
          end
          spec
        end
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
    # Or a URL:
    #
    #   ActiveRecord::Base.establish_connection(
    #     "postgres://myuser:mypass@localhost/somedatabase"
    #   )
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
    # may be returned on an error.
    def self.establish_connection(spec = ENV["DATABASE_URL"])
      resolver = ConnectionSpecification::Resolver.new spec, configurations
      spec = resolver.spec

      unless respond_to?(spec.adapter_method)
        raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
      end

      remove_connection
      connection_handler.establish_connection name, spec
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

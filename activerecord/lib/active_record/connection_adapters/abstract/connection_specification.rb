module ActiveRecord
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    # The connection handler
    cattr_accessor :connection_handler, :instance_writer => false
    @@connection_handler = ConnectionAdapters::ConnectionHandler.new

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
          @@connection_handler.establish_connection(name, spec)
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

    class << self
      # Deprecated and no longer has any effect.
      def allow_concurrency
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.allow_concurrency has been deprecated and no longer has any effect. Please remove all references to allow_concurrency.")
      end

      # Deprecated and no longer has any effect.
      def allow_concurrency=(flag)
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.allow_concurrency= has been deprecated and no longer has any effect. Please remove all references to allow_concurrency=.")
      end

      # Deprecated and no longer has any effect.
      def verification_timeout
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.verification_timeout has been deprecated and no longer has any effect. Please remove all references to verification_timeout.")
      end

      # Deprecated and no longer has any effect.
      def verification_timeout=(flag)
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.verification_timeout= has been deprecated and no longer has any effect. Please remove all references to verification_timeout=.")
      end

      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do database work unrelated
      # to any of the specific Active Records.
      def connection
        retrieve_connection
      end

      def connection_pool
        connection_handler.retrieve_connection_pool(self)
      end

      def retrieve_connection
        connection_handler.retrieve_connection(self)
      end

      def connected?
        connection_handler.connected?(self)
      end

      def remove_connection(klass = self)
        connection_handler.remove_connection(klass)
      end

      delegate :clear_active_connections!, :clear_reloadable_connections!,
        :clear_all_connections!,:verify_active_connections!, :to => :connection_handler
    end
  end
end

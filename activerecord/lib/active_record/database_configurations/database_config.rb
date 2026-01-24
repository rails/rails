# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a +DatabaseConfig+ object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      attr_reader :env_name, :name

      def initialize(env_name, name)
        @env_name = env_name
        @name = name
        @adapter_class = nil
      end

      def adapter_class
        @adapter_class ||= ActiveRecord::ConnectionAdapters.resolve(adapter)
      end

      def inspect # :nodoc:
        "#<#{self.class.name} env_name=#{@env_name} name=#{@name} adapter_class=#{adapter_class}>"
      end

      def new_connection
        adapter_class.new(configuration_hash)
      end

      def validate!
        adapter_class if adapter

        true
      end

      def host
        raise NotImplementedError
      end

      def database
        raise NotImplementedError
      end

      def _database=(database)
        raise NotImplementedError
      end

      def adapter
        raise NotImplementedError
      end

      def min_connections
        raise NotImplementedError
      end

      def max_connections
        raise NotImplementedError
      end

      def min_threads
        raise NotImplementedError
      end

      def max_threads
        raise NotImplementedError
      end

      def max_queue
        raise NotImplementedError
      end

      def query_cache
        raise NotImplementedError
      end

      def checkout_timeout
        raise NotImplementedError
      end

      def reaping_frequency
        raise NotImplementedError
      end

      def idle_timeout
        raise NotImplementedError
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end

      def schema_cache_path
        raise NotImplementedError
      end

      def use_metadata_table?
        raise NotImplementedError
      end

      def seeds?
        raise NotImplementedError
      end
    end
  end
end

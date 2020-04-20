# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a DatabaseConfig object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      attr_reader :env_name, :name

      attr_accessor :owner_name

      def initialize(env_name, name)
        @env_name = env_name
        @name = name
      end

      def spec_name
        @name
      end
      deprecate spec_name: "please use name instead"

      def config
        raise NotImplementedError
      end

      def adapter_method
        "#{adapter}_connection"
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

      def pool
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
    end
  end
end

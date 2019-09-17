# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a DatabaseConfig object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      attr_reader :env_name, :spec_name

      def initialize(env_name, spec_name)
        @env_name = env_name
        @spec_name = spec_name
      end

      def config
        ActiveSupport::Deprecation.warn("DatabaseConfig#config will be removed in 6.2.0 in favor of DatabaseConfigurations#configuration_hash which returns a hash with symbol keys")
        configuration_hash.stringify_keys
      end

      def adapter_method
        "#{adapter}_connection"
      end

      def adapter
        configuration_hash[:adapter]
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def url_config?
        false
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end
    end
  end
end

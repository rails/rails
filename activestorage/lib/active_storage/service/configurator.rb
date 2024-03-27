# frozen_string_literal: true

module ActiveStorage
  class Service::Configurator # :nodoc:
    attr_reader :configurations

    def self.build(service_name, configurations)
      new(configurations).build(service_name)
    end

    def initialize(configurations)
      @configurations = build_configurations(configurations)
    end

    def build(service_name)
      config = config_for(service_name.to_sym)
      resolve(config.fetch(:service)).build(
        **config, configurator: self, name: service_name
      )
    end

    private
      def config_for(name)
        configurations.fetch name do
          raise "Missing configuration for the #{name.inspect} Active Storage service. Configurations available for #{configurations.keys.inspect}"
        end
      end

      def resolve(class_name)
        require "active_storage/service/#{class_name.to_s.underscore}_service"
        ActiveStorage::Service.const_get(:"#{class_name.camelize}Service")
      rescue LoadError
        raise "Missing service adapter for #{class_name.inspect}"
      end

      def build_configurations(configurations)
        if storage_url = ENV["STORAGE_URL"]
          uri = URI.parse(storage_url)
          if uri.scheme
            return ActiveStorage::Service::UrlConfig.new(uri, configurations)
          end
        end

        configurations.deep_symbolize_keys
      end
  end
end

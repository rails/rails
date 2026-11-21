# frozen_string_literal: true

module ActiveStorage
  class Service::Configurator # :nodoc:
    URL_SERVICES = { "disk" => "Disk", "s3" => "S3", "gcs" => "GCS" }.freeze

    attr_reader :configurations

    def self.build(service_name, configurations)
      new(configurations).build(service_name)
    end

    # Converts a URL, such as the value of +STORAGE_URL+, into a service configuration.
    def self.configuration_from_url(url)
      new({}).configuration_from_url(url)
    end

    def initialize(configurations)
      @configurations = configurations.deep_symbolize_keys
    end

    def build(service_name)
      config = config_for(service_name.to_sym)
      resolve(config.fetch(:service)).build(
        **config, configurator: self, name: service_name
      )
    end

    def configuration_from_url(url)
      service = URL_SERVICES.fetch(url[%r{\A([^:/]+)://}, 1]) do
        raise ArgumentError, "STORAGE_URL must start with one of #{URL_SERVICES.keys.map { |scheme| "#{scheme}://" }.join(", ")}"
      end

      { service: service, **resolve(service).service_config_from_url(url) }
    end

    def inspect # :nodoc:
      attrs = configurations.any? ?
        " configurations=[#{configurations.keys.map(&:inspect).join(", ")}]" : ""
      "#<#{self.class}#{attrs}>"
    end

    private
      def config_for(name)
        configurations.fetch name do
          raise "Missing configuration for the #{name.inspect} Active Storage service. Configurations available for #{configurations.keys.inspect}"
        end
      end

      def resolve(class_name)
        service_name = :"#{class_name.camelize}Service"
        unless ActiveStorage::Service.const_defined?(service_name)
          require "active_storage/service/#{class_name.to_s.underscore}_service"
        end
        ActiveStorage::Service.const_get(service_name)
      rescue LoadError
        raise "Missing service adapter for #{class_name.inspect}"
      end
  end
end

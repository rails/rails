# frozen_string_literal: true

# Public bridge for custom Active Storage backends to access the configured
# service registry and default service.
module ActiveStorage::Services
  @registry = nil

  class << self
    attr_accessor :registry
    attr_accessor :default

    def fetch(name, &block)
      registry.fetch(name, &block)
    end

    def setup_from_app_config(app)
      configs = app.config.active_storage.service_configurations ||=
        begin
          config_file = Rails.root.join("config/storage/#{Rails.env}.yml")
          config_file = Rails.root.join("config/storage.yml") unless config_file.exist?
          raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

          ActiveSupport::ConfigurationFile.parse(config_file)
        end

      self.registry = ActiveStorage::Service::Registry.new(configs)
      self.default = app.config.active_storage.service ? registry.fetch(app.config.active_storage.service) : nil

      blob_class = ActiveStorage.blob_class
      blob_class.services = registry if blob_class.respond_to?(:services=)
      blob_class.service = default if blob_class.respond_to?(:service=)

      if defined?(ActiveStorage::Attached::Model) && ActiveStorage::Attached::Model.respond_to?(:pending_service_validations)
        ActiveStorage::Attached::Model.pending_service_validations.each do |model_class, name, service_name|
          registry.fetch(service_name) do
            raise ArgumentError, "Cannot configure service #{service_name.inspect} for #{model_class}##{name}"
          end
        end
        ActiveStorage::Attached::Model.pending_service_validations.clear
      end
    end
  end
end

# frozen_string_literal: true

# :markup: markdown

# Public bridge for custom Active Storage backends to access the configured
# service registry and default service.
module ActiveStorage::Services
  @registry = nil

  class << self
    attr_writer :registry, :default

    # Whether the application's service registry has been initialized.
    def configured?
      !@registry.nil?
    end

    # Returns the configured service registry.
    def registry
      unless configured?
        raise ActiveStorage::ConfigurationError, "Active Storage services have not been configured"
      end

      @registry
    end

    # Returns the default service, which may be unset in a configured registry.
    def default
      registry
      @default
    end

    # Looks up a service in the configured registry.
    #
    # Accepts a service name as a string or symbol.
    def fetch(name, &block)
      registry.fetch(name, &block)
    end

    # Initializes backend services and validates deferred attachment declarations.
    #
    # Pass the loaded blob class from a load hook to configure the newly loaded class
    # during code reloading, before the cached class has been cleared.
    def setup_from_app_config(app, blob_class: ActiveStorage.blob_class)
      configs = app.config.active_storage.service_configurations ||=
        begin
          config_file = Rails.root.join("config/storage/#{Rails.env}.yml")
          config_file = Rails.root.join("config/storage.yml") unless config_file.exist?
          raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

          ActiveSupport::ConfigurationFile.parse(config_file)
        end

      self.registry = ActiveStorage::Service::Registry.new(configs)
      self.default = app.config.active_storage.service ? registry.fetch(app.config.active_storage.service) : nil

      configure_blob(blob_class)

      ActiveStorage::Attached::Builder.declared_classes.each do |owner|
        next if ActiveStorage::Attached::Builder.active_record_owner?(owner)

        owner.attachment_reflections.each_value do |reflection|
          service_name = reflection.options[:service_name]
          unless service_name.is_a?(Proc)
            ActiveStorage::Attached::Model.validate_service_configuration(service_name, owner, reflection.name)
          end
        end
      end
    end

    def configure_blob(blob_class) # :nodoc:
      blob_class.services = registry if blob_class.respond_to?(:services=)
      blob_class.service = default if blob_class.respond_to?(:service=)
    end
  end
end

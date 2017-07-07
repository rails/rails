require "rails/engine"

module ActiveStorage
  class Engine < Rails::Engine # :nodoc:
    config.active_storage = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveStorage

    initializer "active_storage.routes" do
      require "active_storage/disk_controller"

      config.after_initialize do |app|
        app.routes.prepend do
          get "/rails/blobs/:encoded_key" => "active_storage/disk#show", as: :rails_disk_blob
        end
      end
    end

    initializer "active_storage.attached" do
      require "active_storage/attached"

      ActiveSupport.on_load(:active_record) do
        extend ActiveStorage::Attached::Macros
      end
    end

    config.after_initialize do |app|
      config_choice = app.config.active_storage.service
      config_file   = Pathname.new(Rails.root.join("config/storage_services.yml"))

      if config_choice
        raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

        begin
          require "yaml"
          require "erb"
          configs = YAML.load(ERB.new(config_file.read).result) || {}

          if service_configuration = configs[config_choice.to_s].symbolize_keys
            service_name = service_configuration.delete(:service)

            ActiveStorage::Blob.service = ActiveStorage::Service.configure(service_name, service_configuration)
          else
            raise "Couldn't configure Active Storage as #{config_choice} was not found in #{config_file}"
          end
        rescue Psych::SyntaxError => e
          raise "YAML syntax error occurred while parsing #{config_file}. " \
                "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                "Error: #{e.message}"
        rescue => e
          raise e, "Cannot load `Rails.config.active_storage.service`:\n#{e.message}", e.backtrace
        end
      end
    end
  end
end

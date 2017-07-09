require "rails/engine"

module ActiveStorage
  class Engine < Rails::Engine # :nodoc:
    config.active_storage = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveStorage

    initializer "active_storage.logger" do
      require "active_storage/service"

      config.after_initialize do |app|
        ActiveStorage::Service.logger = app.config.active_storage.logger || Rails.logger
      end
    end

    initializer "active_storage.routes" do
      require "active_storage/disk_controller"
      require "active_storage/direct_uploads_controller"

      config.after_initialize do |app|
        app.routes.prepend do
          eval(File.read(File.expand_path("../routes.rb", __FILE__)))
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
      if config_choice = app.config.active_storage.service
        config_file = Pathname.new(Rails.root.join("config/storage_services.yml"))
        raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

        require "yaml"
        require "erb"

        configs =
          begin
            YAML.load(ERB.new(config_file.read).result) || {}
          rescue Psych::SyntaxError => e
            raise "YAML syntax error occurred while parsing #{config_file}. " \
                  "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                  "Error: #{e.message}"
          end

        ActiveStorage::Blob.service =
          begin
            ActiveStorage::Service.configure config_choice, configs
          rescue => e
            raise e, "Cannot load `Rails.config.active_storage.service`:\n#{e.message}", e.backtrace
          end
      end
    end
  end
end

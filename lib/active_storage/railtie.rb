require "rails/railtie"

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
  end
end

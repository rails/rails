require "rails/railtie"

module ActiveVault
  class Railtie < Rails::Railtie # :nodoc:
    config.active_vault = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveVault

    initializer "active_vault.routes" do
      require "active_vault/disk_controller"

      config.after_initialize do |app|
        app.routes.prepend do
          get "/rails/blobs/:encoded_key" => "active_vault/disk#show", as: :rails_disk_blob
        end
      end
    end

    initializer "active_vault.attached" do
      require "active_vault/attached"

      ActiveSupport.on_load(:active_record) do
        extend ActiveVault::Attached::Macros
      end
    end
  end
end

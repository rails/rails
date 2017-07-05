require "rails/railtie"

module ActiveVault
  class Railtie < Rails::Railtie # :nodoc:
    config.action_file = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveVault

    initializer "action_file.routes" do
      require "active_vault/disk_controller"

      config.after_initialize do |app|
        app.routes.prepend do
          get "/rails/blobs/:encoded_key" => "active_vault/disk#show", as: :rails_disk_blob
        end
      end
    end
  end
end

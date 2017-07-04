require "rails/railtie"

module ActiveFile
  class Railtie < Rails::Railtie # :nodoc:
    config.action_file = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveFile

    initializer "action_file.routes" do
      require "active_file/disk_controller"

      config.after_initialize do |app|
        app.routes.prepend do
          get "/rails/blobs/:encoded_key" => "active_file/disk#show", as: :rails_disk_blob
        end
      end
    end
  end
end

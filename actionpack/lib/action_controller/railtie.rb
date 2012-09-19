require "rails"
require "action_controller"
require "action_dispatch/railtie"
require "action_view/railtie"
require "abstract_controller/railties/routes_helpers"
require "action_controller/railties/helpers"

module ActionController
  class Railtie < Rails::Railtie #:nodoc:
    config.action_controller = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActionController

    initializer "action_controller.assets_config", :group => :all do |app|
      app.config.action_controller.assets_dir ||= app.config.paths["public"].first
    end

    initializer "action_controller.set_helpers_path" do |app|
      ActionController::Helpers.helpers_path = app.helpers_paths
    end

    initializer "action_controller.parameters_config" do |app|
      ActionController::Parameters.permit_all_parameters = app.config.action_controller.delete(:permit_all_parameters) { false }
    end

    initializer "action_controller.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_controller

      options.logger               ||= Rails.logger
      options.cache_store          ||= Rails.cache

      options.javascripts_dir      ||= paths["public/javascripts"].first
      options.stylesheets_dir      ||= paths["public/stylesheets"].first
      options.page_cache_directory ||= paths["public"].first

      # Ensure readers methods get compiled
      options.asset_path           ||= app.config.asset_path
      options.asset_host           ||= app.config.asset_host
      options.relative_url_root    ||= app.config.relative_url_root

      ActiveSupport.on_load(:action_controller) do
        include app.routes.mounted_helpers
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes)
        extend ::ActionController::Railties::Helpers

        options.each do |k,v|
          k = "#{k}="
          if respond_to?(k)
            send(k, v)
          elsif !Base.respond_to?(k)
            raise "Invalid option key: #{k}"
          end
        end
      end
    end

    initializer "action_controller.compile_config_methods" do
      ActiveSupport.on_load(:action_controller) do
        config.compile_methods! if config.respond_to?(:compile_methods!)
      end
    end
  end
end

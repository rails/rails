require "rails"
require "action_controller"
require "action_dispatch/railtie"
require "action_view/railtie"
require "active_support/deprecation/proxy_wrappers"
require "active_support/deprecation"

module ActionController
  class Railtie < Rails::Railtie
    config.action_controller = ActiveSupport::OrderedOptions.new

    config.action_controller.singleton_class.tap do |d|
      d.send(:define_method, :session) do
        ActiveSupport::Deprecation.warn "config.action_controller.session has been deprecated. " <<
          "Please use Rails.application.config.session_store instead.", caller
      end

      d.send(:define_method, :session=) do |val|
        ActiveSupport::Deprecation.warn "config.action_controller.session= has been deprecated. " <<
          "Please use config.session_store(name, options) instead.", caller
      end

      d.send(:define_method, :session_store) do
        ActiveSupport::Deprecation.warn "config.action_controller.session_store has been deprecated. " <<
          "Please use Rails.application.config.session_store instead.", caller
      end

      d.send(:define_method, :session_store=) do |val|
        ActiveSupport::Deprecation.warn "config.action_controller.session_store= has been deprecated. " <<
          "Please use config.session_store(name, options) instead.", caller
      end
    end

    initializer "action_controller.logger" do
      ActiveSupport.on_load(:action_controller) { self.logger ||= Rails.logger }
    end

    initializer "action_controller.initialize_framework_caches" do
      ActiveSupport.on_load(:action_controller) { self.cache_store ||= RAILS_CACHE }
    end

    initializer "action_controller.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_controller

      options.assets_dir           ||= paths.public.to_a.first
      options.javascripts_dir      ||= paths.public.javascripts.to_a.first
      options.stylesheets_dir      ||= paths.public.stylesheets.to_a.first
      options.page_cache_directory ||= paths.public.to_a.first
      options.helpers_path         ||= paths.app.helpers.to_a

      ActiveSupport.on_load(:action_controller) do
        include app.routes.url_helpers
        options.each { |k,v| send("#{k}=", v) }
      end
    end

    initializer "action_controller.deprecated_routes" do |app|
      message = "ActionController::Routing::Routes is deprecated. " \
                "Instead, use Rails.application.routes"

      proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(app.routes, message)
      ActionController::Routing::Routes = proxy
    end
  end
end
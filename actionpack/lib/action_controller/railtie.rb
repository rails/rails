require "rails"
require "action_controller"
require "action_dispatch/railtie"
require "action_view/railtie"
require "active_support/core_ext/class/subclasses"
require "active_support/deprecation/proxy_wrappers"
require "active_support/deprecation"

require "action_controller/railties/log_subscriber"
require "action_controller/railties/url_helpers"

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

    log_subscriber :action_controller, ActionController::Railties::LogSubscriber.new

    initializer "action_controller.set_configs" do |app|
      paths = app.config.paths
      ac = app.config.action_controller

      ac.assets_dir           ||= paths.public.to_a.first
      ac.javascripts_dir      ||= paths.public.javascripts.to_a.first
      ac.stylesheets_dir      ||= paths.public.stylesheets.to_a.first
      ac.page_cache_directory ||= paths.public.to_a.first
      ac.helpers_path         ||= paths.app.helpers.to_a

      ActiveSupport.on_load(:action_controller) do
        self.config.merge!(ac)
      end
    end

    initializer "action_controller.logger" do
      ActiveSupport.on_load(:action_controller) { self.logger ||= Rails.logger }
    end

    initializer "action_controller.initialize_framework_caches" do
      ActiveSupport.on_load(:action_controller) { self.cache_store ||= RAILS_CACHE }
    end

    initializer "action_controller.url_helpers" do |app|
      ActiveSupport.on_load(:action_controller) do
        extend ::ActionController::Railties::UrlHelpers.with(app.routes)
      end

      message = "ActionController::Routing::Routes is deprecated. " \
                "Instead, use Rails.application.routes"

      proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(app.routes, message)
      ActionController::Routing::Routes = proxy
    end
  end
end
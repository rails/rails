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

    ad = config.action_dispatch
    config.action_controller.singleton_class.send(:define_method, :session) do
      ActiveSupport::Deprecation.warn "config.action_controller.session has been " \
        "renamed to config.action_dispatch.session.", caller
      ad.session
    end

    config.action_controller.singleton_class.send(:define_method, :session=) do |val|
      ActiveSupport::Deprecation.warn "config.action_controller.session has been " \
        "renamed to config.action_dispatch.session.", caller
      ad.session = val
    end

    config.action_controller.singleton_class.send(:define_method, :session_store) do
      ActiveSupport::Deprecation.warn "config.action_controller.session_store has been " \
        "renamed to config.action_dispatch.session_store.", caller
      ad.session_store
    end

    config.action_controller.singleton_class.send(:define_method, :session_store=) do |val|
      ActiveSupport::Deprecation.warn "config.action_controller.session_store has been " \
        "renamed to config.action_dispatch.session_store.", caller
      ad.session_store = val
    end

    log_subscriber :action_controller, ActionController::Railties::LogSubscriber.new

    initializer "action_controller.logger" do
      ActiveSupport.on_load(:action_controller) { self.logger ||= Rails.logger }
    end

    initializer "action_controller.set_configs" do |app|
      paths = app.config.paths
      ac = app.config.action_controller

      ac.assets_dir      = paths.public.to_a.first
      ac.javascripts_dir = paths.public.javascripts.to_a.first
      ac.stylesheets_dir = paths.public.stylesheets.to_a.first

      ActiveSupport.on_load(:action_controller) do
        self.config.merge!(ac)
      end
    end

    initializer "action_controller.initialize_framework_caches" do
      ActiveSupport.on_load(:action_controller) { self.cache_store ||= RAILS_CACHE }
    end

    initializer "action_controller.set_helpers_path" do |app|
      ActiveSupport.on_load(:action_controller) do
        self.helpers_path = app.config.paths.app.helpers.to_a
      end
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
require "rails"
require "action_controller"
require "action_view/railtie"
require "active_support/core_ext/class/subclasses"
require "active_support/deprecation/proxy_wrappers"

module ActionController
  class Railtie < Rails::Railtie
    railtie_name :action_controller

    require "action_controller/railties/log_subscriber"
    require "action_controller/railties/url_helpers"

    log_subscriber ActionController::Railties::LogSubscriber.new

    initializer "action_controller.logger" do
      ActionController::Base.logger ||= Rails.logger
    end

    initializer "action_controller.set_configs" do |app|
      app.config.action_controller.each do |k,v|
        ActionController::Base.send "#{k}=", v
      end
    end

    initializer "action_controller.initialize_framework_caches" do
      ActionController::Base.cache_store ||= RAILS_CACHE
    end

    initializer "action_controller.set_helpers_path" do |app|
      ActionController::Base.helpers_path = app.config.paths.app.helpers.to_a
    end

    initializer "action_controller.url_helpers" do |app|
      ActionController::Base.extend ::ActionController::Railtie::UrlHelpers.with(app.routes)

      message = "ActionController::Routing::Routes is deprecated. " \
                "Instead, use Rails.application.routes"

      proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(app.routes, message)
      ActionController::Routing::Routes = proxy
    end
  end
end
require "action_controller"
require "rails"

module ActionController
  class Railtie < Rails::Railtie
    railtie_name :action_controller

    require "action_controller/railties/subscriber"
    subscriber ActionController::Railties::Subscriber.new

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
  end
end

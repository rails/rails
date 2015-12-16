require "rails"
require "action_cable"
require "action_cable/helpers/action_cable_helper"
require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  class Railtie < Rails::Railtie # :nodoc:
    config.action_cable = ActiveSupport::OrderedOptions.new
    config.eager_load_namespaces << ActionCable

    initializer "action_cable.helpers" do
      ActiveSupport.on_load(:action_view) do
        include ActionCable::Helpers::ActionCableHelper
      end
    end

    initializer "action_cable.logger" do
      ActiveSupport.on_load(:action_cable) { self.logger ||= ::Rails.logger }
    end

    initializer "action_cable.set_configs" do |app|
      app.paths.add "config/redis/cable", with: "config/redis/cable.yml"

      options = app.config.action_cable

      options.allowed_request_origins ||= "http://localhost:3000" if ::Rails.env.development?

      ActiveSupport.on_load(:action_cable) do
        path = Pathname.new(paths["config/redis/cable"].existent.first)
        self.redis = Rails.application.config_for(redis_path).with_indifferent_access

        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end

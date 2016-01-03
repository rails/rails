require "rails"
require "action_cable"
require "action_cable/helpers/action_cable_helper"
require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  class Railtie < Rails::Engine # :nodoc:
    config.action_cable = ActiveSupport::OrderedOptions.new
    config.action_cable.url = '/cable'

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
      options = app.config.action_cable
      options.allowed_request_origins ||= "http://localhost:3000" if ::Rails.env.development?

      app.paths.add "config/redis/cable", with: "config/redis/cable.yml"

      ActiveSupport.on_load(:action_cable) do
        if (redis_cable_path = Pathname.new(app.config.paths["config/redis/cable"].first)).exist?
          self.redis = Rails.application.config_for(redis_cable_path).with_indifferent_access
        end

        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end

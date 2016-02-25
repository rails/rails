require "rails"
require "action_cable"
require "action_cable/helpers/action_cable_helper"
require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  class Railtie < Rails::Engine # :nodoc:
    config.action_cable = ActiveSupport::OrderedOptions.new
    config.action_cable.mount_path = '/cable'

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

      app.paths.add "config/cable", with: "config/cable.yml"

      ActiveSupport.on_load(:action_cable) do
        if (config_path = Pathname.new(app.config.paths["config/cable"].first)).exist?
          self.cable = Rails.application.config_for(config_path).with_indifferent_access
        end

        if 'ApplicationCable::Connection'.safe_constantize
          self.connection_class = ApplicationCable::Connection
        end

        self.channel_paths = Rails.application.paths['app/channels'].existent

        options.each { |k,v| send("#{k}=", v) }
      end
    end

    initializer "action_cable.routes" do
      config.after_initialize do |app|
        config = app.config
        unless config.action_cable.mount_path.nil?
          app.routes.prepend do
            mount ActionCable.server => config.action_cable.mount_path, internal: true
          end
        end
      end
    end
  end
end

require 'rails/engine'
require 'active_support/ordered_options'
require 'action_cable/helpers/action_cable_helper'

module ActionCable
  class Engine < ::Rails::Engine
    config.action_cable = ActiveSupport::OrderedOptions.new

    config.to_prepare do
      ApplicationController.helper ActionCable::Helpers::ActionCableHelper
    end

    initializer "action_cable.logger" do
      ActiveSupport.on_load(:action_cable) { self.logger ||= ::Rails.logger }
    end

    initializer "action_cable.set_configs" do |app|
      options = app.config.action_cable

      options.allowed_request_origins ||= "http://localhost:3000" if ::Rails.env.development?

      ActiveSupport.on_load(:action_cable) do
        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end

# frozen_string_literal: true

# :markup: markdown

require "rails"
require "action_cable"
require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  class Engine < Rails::Engine # :nodoc:
    config.action_cable = ActiveSupport::OrderedOptions.new
    config.action_cable.mount_path = ActionCable::INTERNAL[:default_mount_path]
    config.action_cable.precompile_assets = true

    initializer "action_cable.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_cable] = ActionCable.deprecator
    end

    initializer "action_cable.helpers" do
      ActiveSupport.on_load(:action_view) do
        include ActionCable::Helpers::ActionCableHelper
      end
    end

    initializer "action_cable.logger" do
      ActiveSupport.on_load(:action_cable) { self.logger ||= ::Rails.logger }
    end

    initializer "action_cable.health_check_application" do
      ActiveSupport.on_load(:action_cable) {
        self.health_check_application = ->(env) { Rails::HealthController.action(:show).call(env) }
      }
    end

    initializer "action_cable.asset" do
      config.after_initialize do |app|
        if app.config.respond_to?(:assets) && app.config.action_cable.precompile_assets
          app.config.assets.precompile += %w( actioncable.js actioncable.esm.js )
        end
      end
    end

    initializer "action_cable.set_configs" do |app|
      options = app.config.action_cable
      options.allowed_request_origins ||= /https?:\/\/localhost:\d+/ if ::Rails.env.development?

      app.paths.add "config/cable", with: "config/cable.yml"

      ActiveSupport.on_load(:action_cable) do
        if (config_path = Pathname.new(app.config.paths["config/cable"].first)).exist?
          self.cable = app.config_for(config_path).to_h.with_indifferent_access
        end

        previous_connection_class = connection_class
        self.connection_class = -> { "ApplicationCable::Connection".safe_constantize || previous_connection_class.call }
        self.filter_parameters += app.config.filter_parameters

        options.each { |k, v| send("#{k}=", v) }
      end
    end

    initializer "action_cable.routes" do
      config.after_initialize do |app|
        config = app.config
        unless config.action_cable.mount_path.nil?
          app.routes.prepend do
            mount ActionCable.server => config.action_cable.mount_path, internal: true, anchor: true
          end
        end
      end
    end

    initializer "action_cable.set_work_hooks" do |app|
      ActiveSupport.on_load(:action_cable) do
        ActionCable::Server::Worker.set_callback :work, :around, prepend: true do |_, inner|
          app.executor.wrap(source: "application.action_cable") do
            # If we took a while to get the lock, we may have been halted in the meantime.
            # As we haven't started doing any real work yet, we should pretend that we never
            # made it off the queue.
            unless stopping?
              inner.call
            end
          end
        end

        wrap = lambda do |_, inner|
          app.executor.wrap(source: "application.action_cable", &inner)
        end
        ActionCable::Channel::Base.set_callback :subscribe, :around, prepend: true, &wrap
        ActionCable::Channel::Base.set_callback :unsubscribe, :around, prepend: true, &wrap

        app.reloader.before_class_unload do
          ActionCable.server.restart
        end
      end
    end
  end
end

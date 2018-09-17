require "rails/engine"

module ActionMailroom
  class Engine < Rails::Engine
    isolate_namespace ActionMailroom
    config.eager_load_namespaces << ActionMailroom

    initializer "action_mailroom.config" do
      config.after_initialize do |app|
        # Configure
      end
    end
  end
end

require "rails/engine"

module ActionMailbox
  class Engine < Rails::Engine
    isolate_namespace ActionMailbox
    config.eager_load_namespaces << ActionMailbox

    initializer "action_mailbox.config" do
      config.after_initialize do |app|
        # Configure
      end
    end
  end
end

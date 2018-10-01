require "rails/engine"

module ActionMailbox
  class Engine < Rails::Engine
    isolate_namespace ActionMailbox
    config.eager_load_namespaces << ActionMailbox

    config.action_mailbox = ActiveSupport::OrderedOptions.new

    initializer "action_mailbox.config" do
      config.after_initialize do |app|
        ActionMailbox.logger = app.config.action_mailbox.logger || Rails.logger
      end
    end
  end
end

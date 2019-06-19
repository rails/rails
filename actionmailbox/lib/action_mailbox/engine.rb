# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "active_support/actionable_error"

require "action_mailbox"

module ActionMailbox
  class Engine < Rails::Engine
    isolate_namespace ActionMailbox
    config.eager_load_namespaces << ActionMailbox

    config.action_mailbox = ActiveSupport::OrderedOptions.new
    config.action_mailbox.incinerate = true
    config.action_mailbox.incinerate_after = 30.days

    config.action_mailbox.queues = ActiveSupport::InheritableOptions.new \
      incineration: :action_mailbox_incineration, routing: :action_mailbox_routing

    initializer "action_mailbox.config" do
      config.after_initialize do |app|
        ActionMailbox.logger = app.config.action_mailbox.logger || Rails.logger
        ActionMailbox.incinerate = app.config.action_mailbox.incinerate.nil? ? true : app.config.action_mailbox.incinerate
        ActionMailbox.incinerate_after = app.config.action_mailbox.incinerate_after || 30.days
        ActionMailbox.queues = app.config.action_mailbox.queues || {}
        ActionMailbox.ingress = app.config.action_mailbox.ingress
      end
    end

    initializer "action_mailbox.actionable_errors" do
      ActiveSupport::ActionableError.define :MissingInstallError, under: ActionMailbox do |actionable|
        actionable.message <<~MESSAGE
          Action Mailbox does not appear to be installed. Do you want to install it now?
        MESSAGE

        actionable.trigger on: ActiveRecord::StatementInvalid, if: -> error do
          error.message.match?(InboundEmail.table_name)
        end

        actionable.action "Install now" do
          Rails::Command.invoke("action_mailbox:install")
          Rails::Command.invoke("db:migrate")
        end
      end
    end
  end
end

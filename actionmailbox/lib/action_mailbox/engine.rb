# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"

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

    config.action_mailbox.storage_service = nil

    guard_load_hooks(:action_mailbox_inbound_email, :action_mailbox_record, :action_mailbox, :action_mailbox_test_case)

    initializer "action_mailbox.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_mailbox] = ActionMailbox.deprecator
    end

    initializer "action_mailbox.config" do
      config.after_initialize do |app|
        ActionMailbox.logger = app.config.action_mailbox.logger || Rails.logger
        ActionMailbox.incinerate = app.config.action_mailbox.incinerate.nil? || app.config.action_mailbox.incinerate
        ActionMailbox.incinerate_after = app.config.action_mailbox.incinerate_after || 30.days
        ActionMailbox.queues = app.config.action_mailbox.queues || {}
        ActionMailbox.ingress = app.config.action_mailbox.ingress
        ActionMailbox.storage_service = app.config.action_mailbox.storage_service
      end
    end
  end
end

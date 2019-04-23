# frozen_string_literal: true

require "active_support/actionable_error"
require "rails/command"

module ActionMailbox
  # Generic base class for all Action Mailbox exceptions.
  class Error < StandardError; end

  # Raised when we detect that Action Mailbox has not been initialized.
  class SetupError < Error
    include ActiveSupport::ActionableError

    def initialize(message = nil)
      return super if message

      super("Action Mailbox uses a table in your application’s database named " \
            "two and active_storage_attachments. To generate it run the following" \
            "command:\n\n        rails action_mailbox:install")
    end

    action "Run action_mailbox:install" do
      Rails::Command.invoke "action_mailbox:install"
    end
  end
end

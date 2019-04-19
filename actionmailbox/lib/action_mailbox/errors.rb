# frozen_string_literal: true

module ActionMailbox
  class Error < StandardError; end

  class InboundEmailTableMissingError < Error
    include ActiveSupport::ActionableError

    action "Install Action Mailbox" do
      Rails::Command.invoke "action_mailbox:install"
    end
  end
end

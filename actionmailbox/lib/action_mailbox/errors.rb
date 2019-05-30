# frozen_string_literal: true

require "active_support/actionable_error"

module ActionMailbox
  # Generic base class for all Action Mailbox exceptions.
  class Error < StandardError; end

  # Raised when we detect that Action Mailbox has not been initialized.
  class InstallError < Error
    include ActiveSupport::ActionableError

    def initialize(message = nil)
      super(message || <<~MESSAGE)
        Action Mailbox does not appear to be installed. Do you want to
        install it now?
      MESSAGE
    end

    trigger on: ActiveRecord::StatementInvalid, if: -> error do
      error.message.match?(InboundEmail.table_name)
    end

    action "Install now" do
      system "./bin/rails action_mailbox:install db:migrate"
    end
  end
end

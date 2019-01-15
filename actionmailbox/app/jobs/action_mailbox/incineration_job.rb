# frozen_string_literal: true

module ActionMailbox
  # You can configure when this `IncinerationJob` will be run as a time-after-processing using the
  # `config.action_mailbox.incinerate_after` or `ActionMailbox.incinerate_after` setting.
  #
  # Since this incineration is set for the future, it'll automatically ignore any `InboundEmail`s
  # that have already been deleted and discard itself if so.
  class IncinerationJob < ActiveJob::Base
    queue_as { ActionMailbox.queues[:incineration] }

    discard_on ActiveRecord::RecordNotFound

    def self.schedule(inbound_email)
      set(wait: ActionMailbox.incinerate_after).perform_later(inbound_email)
    end

    def perform(inbound_email)
      inbound_email.incinerate
    end
  end
end

# frozen_string_literal: true

# :markup: markdown
module ActionMailer
  module QueuedDelivery
    extend ActiveSupport::Concern

    included do
      class_attribute :delivery_job, default: ::ActionMailer::MailDeliveryJob
      class_attribute :deliver_later_queue_name, default: :mailers
    end
  end
end

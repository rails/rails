# frozen_string_literal: true

module ActionMailer
  module QueuedDelivery
    extend ActiveSupport::Concern

    included do
      class_attribute :_delivery_job, instance_accessor: false
      class_attribute :deliver_later_queue_name, instance_accessor: false, default: :mailers
    end

    module ClassMethods
      def delivery_job
        _delivery_job || ::ActionMailer::MailDeliveryJob
      end

      def delivery_job=(job_class)
        self._delivery_job = job_class
      end
    end
  end
end

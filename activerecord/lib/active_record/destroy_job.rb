# frozen_string_literal: true

module ActiveRecord
  class DestroyJob < ActiveJob::Base
    queue_as { ActiveRecord::Base.queues[:destroy] }

    discard_on ActiveJob::DeserializationError

    def perform(record, ensuring: nil)
      record.destroy! if eligible?(record, ensuring)
    end

    private
      def eligible?(record, ensuring)
        ensuring.nil? || record.public_send(ensuring)
      end
  end
end

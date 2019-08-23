# frozen_string_literal: true

 module ActiveRecord
  class DeleteAssociationLaterJob < ActiveJob::Base
    queue_as { ActiveRecord::Base.queues[:destroy] }

     discard_on ActiveJob::DeserializationError

     def perform(records)
      records.each do |r|
        r.delete
      end
    end
  end
end

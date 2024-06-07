# frozen_string_literal: true

module ActiveRecord
  class DestroyAssociationAsyncError < StandardError
  end

  # = Active Record Destroy Association Async Job
  #
  # Job to destroy the records associated with a destroyed record in background.
  class DestroyAssociationAsyncJob < ActiveJob::Base
    queue_as { ActiveRecord.queues[:destroy] }

    discard_on ActiveJob::DeserializationError

    def perform(
      owner_model_name: nil, owner_id: nil,
      association_class: nil, association_ids: nil, association_primary_key_column: nil,
      ensuring_owner_was_method: nil
    )
      association_model = association_class.constantize
      owner_class = owner_model_name.constantize
      owner = owner_class.find_by(owner_class.primary_key => [owner_id])

      if !owner_destroyed?(owner, ensuring_owner_was_method)
        raise DestroyAssociationAsyncError, "owner record not destroyed"
      end

      association_model.where(association_primary_key_column => association_ids).find_each do |r|
        r.destroy
      end
    end

    private
      def owner_destroyed?(owner, ensuring_owner_was_method)
        !owner || (ensuring_owner_was_method && owner.public_send(ensuring_owner_was_method))
      end
  end
end

# frozen_string_literal: true

module ActiveRecord
  class DestroyAssociationAsyncError < StandardError
  end

  class DestroyAssociationAsyncJob < ActiveJob::Base
    queue_as { ActiveRecord.queues[:destroy] }

    discard_on ActiveJob::DeserializationError

    def perform(
          owner_model_name: nil,
          owner_id: nil,
          association_class: nil,
          association_ids: nil,
          association_primary_key_column: nil,
          ensuring_owner_was_method: nil,
          ensuring_owner_destroyed: true
        )
      association_model = association_class.constantize

      # Handle the case when the `has_many` association is replaced with a new
      # set. In such situation, respect the `dependent: :destroy_async`, and
      # delete removed records in the background.
      if ensuring_owner_destroyed
        owner_class = owner_model_name.constantize
        owner = owner_class.find_by(owner_class.primary_key.to_sym => owner_id)

        if !owner_destroyed?(owner, ensuring_owner_was_method)
          raise DestroyAssociationAsyncError, "owner record not destroyed"
        end
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

# frozen_string_literal: true

module ActiveRecord
  class DestroyAssociationLaterError < StandardError
  end

  # Destroy record association in a background job.
  #
  #  class ParentNode < ApplicationRecord
  #    has_one :child, dependent: :destroy_later
  #   end
  #
  #   +destroy_later+ param adds an +after_destroy+ callback that schedules an ActiveRecord::DestroyAssocitionLaterJob.
  #
  class DestroyAssociationLaterJob < ActiveJob::Base
    queue_as { ActiveRecord::Base.queues[:destroy] }

    discard_on ActiveJob::DeserializationError

    def perform(owner_model_name: nil, owner_id: nil, assoc_class: nil,
                assoc_ids: nil, assoc_primary_key_column: nil,
                owner_ensuring_destroy_method: nil)
      assoc_model = assoc_class.constantize
      owner_class = owner_model_name.constantize
      owner = owner_class
        .where(owner_class.primary_key.to_sym => owner_id)

      if !owner_destroyed?(owner, owner_ensuring_destroy_method)
        raise DestroyAssociationLaterError, "owner record not destroyed"
      end
      assoc_model.where(assoc_primary_key_column => assoc_ids).find_each do |r|
        r.destroy
      end
    end

    private
      def owner_destroyed?(owner, owner_ensuring_destroy_method)
        return true if owner.empty?
        return owner.first.public_send(owner_ensuring_destroy_method) unless owner_ensuring_destroy_method.nil?
        false
      end
  end
end

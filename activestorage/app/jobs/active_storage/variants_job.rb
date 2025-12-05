# frozen_string_literal: true

class ActiveStorage::VariantsJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound, ActiveStorage::UnrepresentableError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, variations)
    variations.each do |transformations|
      blob.preprocessed(transformations)
    end
  end
end

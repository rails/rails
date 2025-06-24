# frozen_string_literal: true

class ActiveStorage::PreviewImageJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:preview_image] }

  discard_on ActiveRecord::RecordNotFound, ActiveStorage::UnrepresentableError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, variations)
    blob.preview({}).processed

    variations.each do |transformations|
      blob.preprocessed(transformations)
    end
  end
end

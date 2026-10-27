# frozen_string_literal: true

# :markup: markdown
class ActiveStorage::TransformJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound, ActiveJob::DeserializationError::RecordNotFound
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, transformations)
    blob.representation(transformations).processed
  end
end

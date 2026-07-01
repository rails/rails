# frozen_string_literal: true

class ActiveStorage::TransformJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveStorage::RecordNotFound
  discard_on ActiveRecord::RecordNotFound if defined?(::ActiveRecord::Base)
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, transformations)
    blob.representation(transformations).processed
  end
end

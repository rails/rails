# frozen_string_literal: true

class ActiveStorage::SyncMetadataJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:sync_metadata] }

  discard_on ActiveStorage::RecordNotFound
  discard_on ActiveRecord::RecordNotFound if defined?(::ActiveRecord::Base)
  retry_on ActiveStorage::Deadlocked, attempts: 10, wait: :polynomially_longer
  retry_on ActiveRecord::Deadlocked, attempts: 10, wait: :polynomially_longer if defined?(::ActiveRecord::Base)

  def perform(blob)
    blob.sync_metadata
  end
end

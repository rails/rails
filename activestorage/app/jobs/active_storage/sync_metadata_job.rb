# frozen_string_literal: true

class ActiveStorage::SyncMetadataJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:sync_metadata] }

  discard_on ActiveRecord::RecordNotFound
  retry_on ActiveRecord::Deadlocked, attempts: 10, wait: :polynomially_longer

  def perform(blob)
    blob.sync_metadata
  end
end

ActiveSupport.run_load_hooks :active_storage_sync_metadata_job, ActiveStorage::SyncMetadataJob

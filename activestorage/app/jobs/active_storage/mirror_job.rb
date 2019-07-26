# frozen_string_literal: true

# Provides asynchronous mirroring of directly-uploaded blobs.
class ActiveStorage::MirrorJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:mirror] }

  discard_on ActiveStorage::FileNotFoundError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :exponentially_longer

  def perform(key, checksum:)
    ActiveStorage::Blob.service.try(:mirror, key, checksum: checksum)
  end
end

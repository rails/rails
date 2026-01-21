# frozen_string_literal: true

require "active_support/core_ext/object/try"

# Provides asynchronous mirroring of directly-uploaded blobs.
class ActiveStorage::MirrorJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:mirror] }

  discard_on ActiveStorage::FileNotFoundError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(key, checksum:)
    if blob = ActiveStorage::Blob.find_by(key: key)
      blob.service.try(:mirror, blob.key, checksum: blob.checksum)
    else
      ActiveStorage::Blob.service.try(:mirror, key, checksum: checksum)
    end
  end
end

# frozen_string_literal: true

require "active_support/core_ext/object/try"

# Provides asynchronous mirroring of directly-uploaded blobs.
class ActiveStorage::MirrorJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:mirror] }

  discard_on ActiveStorage::FileNotFoundError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(key, checksum:, service_name: nil)
    service = service_name ? ActiveStorage::Blob.services.fetch(service_name) : ActiveStorage::Blob.service
    service.try(:mirror, key, checksum: checksum)
  end
end

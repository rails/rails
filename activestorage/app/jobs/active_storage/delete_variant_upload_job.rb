# frozen_string_literal: true

# Deletes a variant upload whose blob row has rolled back.
class ActiveStorage::DeleteVariantUploadJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:purge] }

  # A retry must survive a later rollback of the enclosing transaction.
  self.enqueue_after_transaction_commit = false

  retry_on StandardError, attempts: 10, wait: :polynomially_longer

  def perform(service_name, key)
    ActiveStorage::Blob.services.fetch(service_name).primary_service.delete(key)
  end
end

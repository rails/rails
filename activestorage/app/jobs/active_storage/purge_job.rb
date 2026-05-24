# frozen_string_literal: true

# Provides asynchronous purging of ActiveStorage::Blob records via ActiveStorage::Blob#purge_later.
class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:purge] }

  discard_on ActiveStorage::RecordNotFound
  discard_on ActiveRecord::RecordNotFound if defined?(::ActiveRecord::Base)
  retry_on ActiveStorage::Deadlocked, attempts: 10, wait: :polynomially_longer
  retry_on ActiveRecord::Deadlocked, attempts: 10, wait: :polynomially_longer if defined?(::ActiveRecord::Base)

  def perform(blob)
    blob.purge
  end
end

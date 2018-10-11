# frozen_string_literal: true

# Provides asynchronous purging of ActiveStorage::Blob records via ActiveStorage::Blob#purge_later.
class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  discard_on ActiveRecord::RecordNotFound
  retry_on ActiveRecord::Deadlocked, attempts: 10, wait: :exponentially_longer

  def perform(blob)
    blob.purge
  end
end

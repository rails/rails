# frozen_string_literal: true

# Provides asynchronous purging of ActiveStorage::Blob records via ActiveStorage::Blob#purge_later.
class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveRecord::InvalidForeignKey

  def perform(blob)
    blob.purge
  end
end

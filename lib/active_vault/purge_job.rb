class ActiveVault::PurgeJob < ActiveJob::Base
  retry_on ActiveVault::StorageException

  def perform(blob)
    blob.purge
  end
end

class ActiveFile::PurgeJob < ActiveJob::Base
  retry_on ActiveFile::StorageException

  def perform(blob)
    blob.purge
  end
end

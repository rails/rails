require "active_job"

class ActiveVault::PurgeJob < ActiveJob::Base
  # FIXME: Limit this to a custom ActiveVault error
  retry_on StandardError

  def perform(attachment_or_blob)
    attachment_or_blob.purge
  end
end

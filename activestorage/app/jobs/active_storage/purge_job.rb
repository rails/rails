# frozen_string_literal: true

# Provides asynchronous purging of ActiveStorage::Blob records via ActiveStorage::Blob#purge_later.
class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  # FIXME: Limit this to a custom ActiveStorage error
  retry_on StandardError

  # All parameters have to be keyword arguments for keyword arguments to work with ActiveJob
  def perform(blob:, check_unattached: false)
    return unless blob.present? # Because blob is a keyword argument, it might not exist here
    blob.purge unless check_unattached && blob.attachments.any?
  end
end

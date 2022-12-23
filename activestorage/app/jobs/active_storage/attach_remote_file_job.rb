# frozen_string_literal: true

require "open-uri"

# Downloads and attaches a File from a URL
class ActiveStorage::AttachRemoteFileJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:attach_remote_file] }

  discard_on ActiveRecord::RecordNotFound, OpenURI::HTTPError

  def perform(record, name, url)
    attachment = record.public_send(name)
    uri = URI.parse(url)

    attachment.attach(io: uri.open, filename: File.basename(uri.path))
  end
end

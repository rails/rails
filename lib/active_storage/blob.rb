require "active_storage/service"
require "active_storage/filename"
require "active_storage/purge_job"

# Schema: id, key, filename, content_type, metadata, byte_size, checksum, created_at
class ActiveStorage::Blob < ActiveRecord::Base
  self.table_name = "active_storage_blobs"

  has_secure_token :key
  store :metadata, coder: JSON

  class_attribute :service

  class << self
    def build_after_upload(io:, filename:, content_type: nil, metadata: nil)
      new.tap do |blob|
        blob.filename     = filename
        blob.content_type = content_type
        blob.metadata     = metadata

        blob.upload io
      end
    end

    def create_after_upload!(io:, filename:, content_type: nil, metadata: nil)
      build_after_upload(io: io, filename: filename, content_type: content_type, metadata: metadata).tap(&:save!)
    end
  end

  # We can't wait until the record is first saved to have a key for it
  def key
    self[:key] ||= self.class.generate_unique_secure_token
  end

  def filename
    ActiveStorage::Filename.new(self[:filename])
  end

  def url(expires_in: 5.minutes, disposition: :inline)
    service.url key, expires_in: expires_in, disposition: disposition, filename: filename
  end


  def upload(io)
    self.checksum  = compute_checksum_in_chunks(io)
    self.byte_size = io.size

    service.upload(key, io, checksum: checksum)
  end

  def download
    service.download key
  end


  def delete
    service.delete key
  end

  def purge
    delete
    destroy
  end

  def purge_later
    ActiveStorage::PurgeJob.perform_later(self)
  end


  private
    def compute_checksum_in_chunks(io)
      Digest::MD5.new.tap do |checksum|
        while chunk = io.read(5.megabytes)
          checksum << chunk
        end

        io.rewind
      end.base64digest
    end
end

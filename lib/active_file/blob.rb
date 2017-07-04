require "active_file/site"
require "active_file/filename"

# Schema: id, key, filename, content_type, metadata, byte_size, checksum, created_at
class ActiveFile::Blob < ActiveRecord::Base
  self.table_name = "rails_blobs"

  has_secure_token :key
  store :metadata, coder: JSON

  class_attribute :site

  class << self
    def build_after_upload(io:, filename:, content_type: nil, metadata: nil)
      new.tap do |blob|
        blob.filename = name
        blob.content_type = content_type # Marcel::MimeType.for(data, name: name, declared_type: content_type)
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
    ActiveFile::Filename.new(self[:filename])
  end

  def url(expires_in: 5.minutes, disposition: :inline)
    site.url key, expires_in: expires_in, disposition: disposition, filename: filename
  end


  def upload(io)
    site.upload(key, io)

    self.checksum  = site.checksum(key)
    self.byte_size = site.byte_size(key)
  end

  def download
    site.download key
  end


  def delete
    site.delete key
  end

  def purge
    delete
    destroy
  end

  def purge_later
    ActiveFile::PurgeJob.perform_later(self)
  end
end

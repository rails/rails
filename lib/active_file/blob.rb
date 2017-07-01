require "active_file/site"

# Schema: id, key, filename, content_type, metadata, byte_size, digest, created_at
class ActiveFile::Blob < ActiveRecord::Base
  self.table_name = "active_file_blobs"

  has_secure_token :key
  store :metadata, coder: JSON

  class_attribute :verifier, default: -> { Rails.application.message_verifier('ActiveFile') }
  class_attribute :site

  class << self
    def find_verified(signed_id)
      find(verifier.verify(signed_id))
    end

    def build_after_upload(data:, filename:, content_type: nil, metadata: nil)
      new.tap do |blob|
        blob.filename = name
        blob.content_type = content_type # Marcel::MimeType.for(data, name: name, declared_type: content_type)
        blob.upload data
      end
    end

    def create_after_upload!(data:, filename:, content_type: nil, metadata: nil)
      build_after_upload(data: data, filename: filename, content_type: content_type, metadata: metadata).tap(&:save!)
    end
  end

  # We can't wait until the record is first saved to have a key for it
  def key
    self[:key] ||= self.class.generate_unique_secure_token
  end

  def filename
    Filename.new(filename)
  end


  def upload(data)
    site.upload key, data
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

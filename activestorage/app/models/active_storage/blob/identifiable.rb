# frozen_string_literal: true

module ActiveStorage::Blob::Identifiable
  def identify
    update! content_type: identify_content_type, identified: true unless identified?
  end

  def identified?
    identified
  end

  private
    def identify_content_type
      Marcel::MimeType.for download_identifiable_chunk, name: filename.to_s, declared_type: content_type
    end

    def download_identifiable_chunk
      if byte_size.positive?
        service.download_chunk key, 0...4.kilobytes
      else
        ""
      end
    end

    def content_empty?
      service.bucket.object(key).content_length.zero?
    end
end

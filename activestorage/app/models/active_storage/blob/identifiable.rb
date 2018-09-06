# frozen_string_literal: true

module ActiveStorage::Blob::Identifiable
  def identify
    unless identified?
      update! content_type: identify_content_type, identified: true
      update_service_metadata
    end
  end

  def identified?
    identified
  end

  private
    def identify_content_type
      Marcel::MimeType.for download_identifiable_chunk, name: filename.to_s, declared_type: content_type
    end

    def download_identifiable_chunk
      service.download_chunk key, 0...4.kilobytes
    end

    def update_service_metadata
      service.update_metadata key, service_metadata if service_metadata.any?
    end
end

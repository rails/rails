# frozen_string_literal: true

module ActiveStorage::Blob::Identifiable
  def identify
    identify_without_saving
    save!
  end

  def identify_without_saving
    unless identified?
      self.content_type = identify_content_type
      self.identified = true
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
      if byte_size.positive?
        service.download_chunk key, 0...4.kilobytes
      else
        ''
      end
    end
end

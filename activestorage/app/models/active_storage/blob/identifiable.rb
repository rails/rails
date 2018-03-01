# frozen_string_literal: true

module ActiveStorage::Blob::Identifiable
  def identify
    update!(content_type: identification.content_type, identified: true) unless identified?
  end

  def identified?
    identified
  end

  private
    def identification
      ActiveStorage::Identification.new self
    end
end

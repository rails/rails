# frozen_string_literal: true

module ActiveStorage::EnsureBlobAccessible # :nodoc:
  extend ActiveSupport::Concern

  included do
    before_action :ensure_blob_accessible, unless: :publicly_accessible_blob?
  end

  private
    def publicly_accessible_blob?
      ActiveStorage.blobs_always_publicly_accessible || attachment_publicly_accessible?
    end

    def attachment_publicly_accessible?
      @blob.attachments.any? do |attachment|
        attachment.record.class.attachment_reflections[attachment.name].publicly_accessible?(attachment)
      end
    end

    def ensure_blob_accessible
      head :forbidden
    end
end

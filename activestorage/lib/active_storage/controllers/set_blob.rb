# frozen_string_literal: true

module ActiveStorage::SetBlob # :nodoc:
  extend ActiveSupport::Concern

  included do
    before_action :set_blob
  end

  private
    def set_blob
      @blob = self.class.blob_class.find_signed!(params[:signed_blob_id] || params[:signed_id])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      head :not_found
    end
end

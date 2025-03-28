# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
module ActiveStorage::Controllers::Blobs::DirectUploads
  extend ActiveSupport::Concern

  included do
    def create
      blob = self.class.blob_class.create_before_direct_upload!(**blob_args)
      render json: direct_upload_json(blob)
    end

    private
      def blob_args
        params.expect(blob: [:filename, :byte_size, :checksum, :content_type, metadata: {}]).to_h.symbolize_keys
      end
  
      def direct_upload_json(blob)
        blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload
        })
      end
  end
end

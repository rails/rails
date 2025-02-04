# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    direct_upload_params = blob_args

    direct_upload_params[:checksum] = if direct_upload_params[:checksum].is_a?(Hash)
      # Accept {checksum: {digest:, algorithm:}}
      ActiveStorage::Checksum.new(direct_upload_params[:checksum][:digest], direct_upload_params[:checksum][:algorithm])
    else
      # Accept "<MD5digest>" or "<algorithm>:<digest>"
      ActiveStorage::Checksum.load(direct_upload_params[:checksum])
    end

    blob = ActiveStorage::Blob.create_before_direct_upload!(**direct_upload_params)

    render json: direct_upload_json(blob)
  end

  private
    def blob_args
      params.expect(blob: [:filename, :byte_size, :checksum, { checksum: [:algorithm, :digest] }, :content_type, metadata: {}]).to_h.deep_symbolize_keys
    end

    def direct_upload_json(blob)
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      })
    end
end

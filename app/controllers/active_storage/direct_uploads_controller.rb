# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
class ActiveStorage::DirectUploadsController < ActionController::Base
  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(blob_args)
    render json: { upload_to_url: blob.url_for_direct_upload, signed_blob_id: blob.signed_id }
  end

  private
    def blob_args
      params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, :metadata).to_h.symbolize_keys
    end
end

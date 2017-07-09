require "action_controller"
require "active_storage/blob"

class ActiveStorage::DirectUploadsController < ActionController::Base
  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(blob_args)
    render json: { url: blob.url_for_direct_upload, sgid: blob.to_sgid.to_param }
  end

  private
    def blob_args
      params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, :metadata).to_h.symbolize_keys
    end
end

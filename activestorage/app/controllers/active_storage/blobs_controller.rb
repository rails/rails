# Take a signed permanent reference for a blob and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob references, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::BlobsController < ActionController::Base
  def show
    if blob = find_signed_blob
      redirect_to blob.service_url(disposition: disposition_param)
    else
      head :not_found
    end
  end

  private
    def find_signed_blob
      ActiveStorage::Blob.find_signed(params[:signed_id])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end
end

# frozen_string_literal: true

# Take a signed permanent reference for a blob and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob references, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::BlobsController < ActionController::Base
  def show
    if blob = ActiveStorage::Blob.find_signed(params[:signed_id])
      expires_in ActiveStorage::Blob.service.url_expires_in
      redirect_to blob.service_url(disposition: params[:disposition])
    else
      head :not_found
    end
  end
end

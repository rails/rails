# frozen_string_literal: true

# Take a signed permanent reference for a variant and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob and variation reference, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::VariantsController < ActionController::Base
  def show
    if blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id])
      expires_in ActiveStorage::Blob.service.url_expires_in
      redirect_to ActiveStorage::Variant.new(blob, params[:variation_key]).processed.service_url(disposition: params[:disposition])
    else
      head :not_found
    end
  end
end

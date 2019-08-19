# frozen_string_literal: true

# Take a signed permanent reference for a blob representation and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob and variation reference, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::RepresentationsController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    expires_in ActiveStorage.service_urls_expire_in
    redirect_to @blob.representation(params[:variation_key]).processed.service_url(disposition: params[:disposition])
  end

  def proxy
    expires_in params[:proxy_urls_expire_in], public: params[:proxy_urls_public]

    representation = @blob.representation(params[:variation_key]).processed

    response.headers["Content-Disposition"] = representation.image.blob.disposition(params[:disposition])
    response.headers["Content-Type"] = representation.image.content_type

    @blob.service.download(representation.key) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end

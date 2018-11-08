# frozen_string_literal: true

# Take a signed permanent reference for a blob representation and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob and variation reference, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::RepresentationsController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    case ActiveStorage.delivery_method
    when :redirect
      redirect
    when :proxy
      proxy
    end
  end

  def redirect
    expires_in ActiveStorage.service_urls_expire_in
    redirect_to @blob.representation(params[:variation_key]).processed.service_url(disposition: params[:disposition])
  end

  def proxy
    expires_in ActiveStorage.proxy_urls_expire_in

    response.headers['Content-Type'] = params[:content_type]
    response.headers['Content-Disposition'] = params[:disposition]

    @variant = @blob.representation(params[:variation_key]).processed

    @blob.service.download(@variant.key) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end

# frozen_string_literal: true

# Take a signed permanent reference for a blob and turn it into an expiring service URL for download.
#
# WARNING: All Active Storage controllers are publicly accessible by default. If your files require
# access control consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Blobs::RedirectController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    expires_in ActiveStorage.service_urls_expire_in
    redirect_to @blob.url(disposition: params[:disposition]), allow_other_host: true
  end
end

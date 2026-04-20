# frozen_string_literal: true

# Finds a blob by a +signed_id+ and redirects to a blob's expiring service URL.
#
# The +signed_id+s make URLs hard to guess but permanent by design, allowing the URLs to be cached.
#
# The URLs created for this controller are set to never expire by default.
# To make URLs expire, pass the +expires_in+ option when generating the URL:
#
#   rails_storage_redirect_url(blob, expires_in: 1.minute)
#
# Or set the default for all Active Storage URLs:
#
#   config.active_storage.urls_expire_in = 1.day
#
# The service URLs are set to expire in 5 minutes by default.
# The default can be changed for all service URLs:
#
#   config.active_storage.service_urls_expire_in = 1.hour
#
# WARNING: All Active Storage controllers are publicly accessible by default.
# Anyone who knows the URL can access the file, even if the rest of your application requires
# authentication. If your files require access control consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Blobs::RedirectController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    expires_in ActiveStorage.service_urls_expire_in
    redirect_to @blob.url(disposition: params[:disposition]), allow_other_host: true
  end
end

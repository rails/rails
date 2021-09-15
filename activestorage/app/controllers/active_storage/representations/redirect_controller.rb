# frozen_string_literal: true

# Take a signed permanent reference for a blob representation and turn it into an expiring service URL for download.
#
# WARNING: All Active Storage controllers are publicly accessible by default. The
# generated URLs are hard to guess, but permanent by design. If your files
# require a higher level of protection consider implementing
# {Authenticated Controllers}[https://edgeguides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Representations::RedirectController < ActiveStorage::Representations::BaseController
  def show
    expires_in ActiveStorage.service_urls_expire_in
    redirect_to @representation.url(disposition: params[:disposition]), allow_other_host: true
  end
end

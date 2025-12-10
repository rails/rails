# frozen_string_literal: true

# Proxy files through application. This avoids having a redirect and makes files easier to cache.
#
# WARNING: All Active Storage controllers are publicly accessible by default. The
# generated URLs are hard to guess, but permanent by design. If your files
# require a higher level of protection consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Representations::ProxyController < ActiveStorage::Representations::BaseController
  include ActiveStorage::Streaming
  include ActiveStorage::DisableSession

  def show
    http_cache_forever public: true do
      if (disposition = params[:disposition]).is_a?(ActionController::Parameters)
        disposition, filename = disposition[:disposition], disposition[:filename]
      end

      send_blob_stream @representation, disposition: disposition, filename: filename
    end
  end
end

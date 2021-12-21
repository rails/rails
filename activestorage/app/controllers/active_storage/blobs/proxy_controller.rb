# frozen_string_literal: true

# Proxy files through application. This avoids having a redirect and makes files easier to cache.
#
# WARNING: All Active Storage controllers are publicly accessible by default. The
# generated URLs are hard to guess, but permanent by design. If your files
# require a higher level of protection consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Blobs::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    if request.headers["Range"].present?
      send_blob_byte_range_data @blob, request.headers["Range"]
    else
      http_cache_forever public: true do
        response.headers["Accept-Ranges"] = "bytes"
        response.headers["Content-Length"] = @blob.byte_size.to_s

        send_blob_stream @blob, disposition: params[:disposition]
      end
    end
  end
end

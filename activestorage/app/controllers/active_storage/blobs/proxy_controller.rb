# frozen_string_literal: true

# Finds a blob by a +signed_id+ and proxies the file through the application.
# The blob is streamed from storage directly to the response. This avoids having
# a redirect and makes files easier to cache.
#
# The +signed_id+s make URLs hard to guess but permanent by design, allowing the URLs to be cached.
# The response sets the HTTP cache to public and allows browsers and proxies to cache it indefinitely.
#
# The URLs created for this controller are set to never expire by default.
# To make URLs expire, pass the +expires_in+ option when generating the URL:
#
#   rails_storage_proxy_url(blob, expires_in: 1.minute)
#
# Or set the default for all Active Storage URLs:
#
#   config.active_storage.urls_expire_in = 1.day
#
# WARNING: All Active Storage controllers are publicly accessible by default.
# Anyone who knows the URL can access the file, even if the rest of your application requires
# authentication. If your files require access control consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
class ActiveStorage::Blobs::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::Streaming
  include ActiveStorage::DisableSession

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

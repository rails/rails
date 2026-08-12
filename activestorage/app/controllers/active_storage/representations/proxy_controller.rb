# frozen_string_literal: true

# Finds a representation by a +signed_id+ and a +variation_key+, and proxies the file through the application.
# The representation is streamed from storage directly to the response. This avoids having
# a redirect and makes files easier to cache.
#
# The <tt>signed_id</tt>s make URLs hard to guess but permanent by design, allowing the URLs to be cached.
# The response sets the HTTP cache to public and allows browsers and proxies to cache it indefinitely.
#
# The URLs created for this controller are set to never expire by default.
# To make URLs expire, pass the +expires_in+ option when generating the URL:
#
#   rails_storage_proxy_url(representation, expires_in: 1.minute)
#
# Or set the default for all Active Storage URLs:
#
#   config.active_storage.urls_expire_in = 1.day
#
# WARNING: All Active Storage controllers are publicly accessible by default.
# Anyone who knows the URL can access the file, even if the rest of your application requires
# authentication. If your files require access control consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
#
# Authorization can be added through the +:active_storage_representations_proxy_controller+ load hook:
#
#   ActiveSupport.on_load(:active_storage_representations_proxy_controller) do
#     include MyBlobAuthorization
#   end
#
# WARNING: Responses are publicly cacheable by default. You must set +public_cache+
# to +false+ so that CDNs do not cache authorized files.
class ActiveStorage::Representations::ProxyController < ActiveStorage::Representations::BaseController
  include ActiveStorage::Streaming
  include ActiveStorage::DisableSession

  class_attribute :public_cache, default: true

  def show
    http_cache_forever public: public_cache do
      send_blob_stream @representation, disposition: params[:disposition]
    end
  end
end

ActiveSupport.run_load_hooks :active_storage_representations_proxy_controller, ActiveStorage::Representations::ProxyController

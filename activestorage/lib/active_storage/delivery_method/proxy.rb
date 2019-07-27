# # frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod::Proxy < DeliveryMethod
    class << self
      def url_options(override_options)
        if ActiveStorage.proxy_urls_host
          { host: ActiveStorage.proxy_urls_host }.merge(override_options || {})
        else
          { only_path: true }.merge(override_options || {})
        end
      end
    
      def representation_url(representation, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_blob_representation_proxy,
          representation.blob.signed_id,
          representation.variation.key,
          representation.blob.filename,
          self.url_options(url_options)
        )
      end
    
      def blob_url(signed_id, filename, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_blob_proxy,
          signed_id,
          filename,
          self.url_options(url_options)
        )
      end
    end
  end
end

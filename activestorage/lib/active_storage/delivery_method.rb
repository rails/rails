# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod
    class << self
      def representation_url(representation, url_options: nil, delivery_method: nil)
        raise NotImplementedError
      end

      def blob_url(signed_id, filename, url_options: nil, delivery_method: nil)
        raise NotImplementedError
      end

      def select(delivery_method)
        ActiveStorage.delivery_methods.find do |dm|
          dm.name.sub("ActiveStorage::DeliveryMethod::", "").downcase == delivery_method.to_s
        end
      end

      def url_options(override_options)
        if ActiveStorage.proxy_urls_host
          { host: ActiveStorage.proxy_urls_host }.merge(override_options || {})
        else
          { only_path: true }.merge(override_options || {})
        end
      end
    end
  end
end

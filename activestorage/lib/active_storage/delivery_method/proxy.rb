# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod::Proxy < DeliveryMethod
    class << self
      def representation_url(representation, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_blob_representation_proxy,
          representation.blob.signed_id,
          representation.variation.key,
          representation.blob.filename,
          ActiveStorage::DeliveryMethod.url_options(url_options)
        )
      end

      def blob_url(signed_id, filename, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_blob_proxy,
          signed_id,
          filename,
          ActiveStorage::DeliveryMethod.url_options(url_options)
        )
      end
    end
  end
end

# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod::Redirect < DeliveryMethod
    class << self
      def representation_url(representation, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_blob_representation,
          representation.blob.signed_id,
          representation.variation.key,
          representation.blob.filename,
          ActiveStorage::DeliveryMethod.url_options(url_options)
        )
      end

      def blob_url(signed_id, filename, url_options: nil)
        Rails.application.routes.url_helpers.route_for(
          :rails_service_blob,
          signed_id,
          filename,
          ActiveStorage::DeliveryMethod.url_options(url_options)
        )
      end
    end
  end
end

# frozen_string_literal: true

module ActiveStorage
  def self.route_representation(representation, url_options: nil, delivery_method: nil)
    deliver_via = delivery_method || representation.attachment&.delivery_method || ActiveStorage.delivery_method

    route = deliver_via == :proxy ? :rails_blob_representation_proxy : :rails_blob_representation

    Rails.application.routes.url_helpers.route_for(
      route,
      representation.blob.signed_id,
      representation.variation.key,
      representation.blob.filename,
      ActiveStorage.url_options(url_options)
    )
  end

  def self.route_blob(signed_id, filename, url_options: nil, delivery_method: nil)
    deliver_via = delivery_method || ActiveStorage.delivery_method

    route = deliver_via == :proxy ? :rails_blob_proxy : :rails_service_blob

    Rails.application.routes.url_helpers.route_for(
      route,
      signed_id,
      filename,
      ActiveStorage.url_options(url_options)
    )
  end
end

# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod
    def representation_url(representation, url_options: nil, delivery_method: nil)
      raise NotImplementedError
    end

    def blob_url(signed_id, filename, url_options: nil, delivery_method: nil)
      raise NotImplementedError
    end
  end
end

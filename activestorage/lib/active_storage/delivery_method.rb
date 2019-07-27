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
          dm.name.sub('ActiveStorage::DeliveryMethod::', '').downcase == delivery_method.to_s
        end          
      end
    end
  end
end

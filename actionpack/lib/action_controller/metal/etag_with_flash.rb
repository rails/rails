# frozen_string_literal: true

module ActionController
  # When you're using the flash, it's generally used as a conditional on the view.
  # This means the content of the view depends on the flash. Which in turn means
  # that the ETag for a response should be computed with the content of the flash
  # in mind. This does that by including the content of the flash as a component
  # in the ETag that's generated for a response.
  module EtagWithFlash
    extend ActiveSupport::Concern

    include ActionController::ConditionalGet

    included do
      etag { flash unless flash.empty? }
    end
  end
end

# frozen_string_literal: true

module ActionController
  # Allows configuring default headers that will be automatically merged into
  # each response.
  module DefaultHeaders
    extend ActiveSupport::Concern

    module ClassMethods
      def make_response!(request)
        ActionDispatch::Response.create.tap do |res|
          res.request = request
        end
      end
    end
  end
end

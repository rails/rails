# frozen_string_literal: true

require "active_storage/controllers/set_current"

module ActiveStorage::Controllers::Representations::Base
  extend ActiveSupport::Concern

  included do
    include ActiveStorage::SetBlob

    before_action :set_representation

    private
      def blob_scope
        self.class.blob_class.scope_for_strict_loading
      end

      def set_representation
        @representation = @blob.representation(params[:variation_key]).processed
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        head :not_found
      end
  end
end

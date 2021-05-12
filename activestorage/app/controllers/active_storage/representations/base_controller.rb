# frozen_string_literal: true

class ActiveStorage::Representations::BaseController < ActiveStorage::BaseController #:nodoc:
  include ActiveStorage::SetBlob

  before_action :set_representation

  private
    def set_representation
      @representation = @blob.representation(params[:variation_key]).processed
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      head :not_found
    end
end

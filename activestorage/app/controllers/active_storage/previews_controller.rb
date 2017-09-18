# frozen_string_literal: true

class ActiveStorage::PreviewsController < ActionController::Base
  def show
    if blob = find_signed_blob
      expires_in 5.minutes # service_url defaults to 5 minutes
      redirect_to ActiveStorage::Preview.new(blob, decoded_variation).processed.service_url(disposition: disposition_param)
    else
      head :not_found
    end
  end

  private
    def find_signed_blob
      ActiveStorage::Blob.find_signed(params[:signed_blob_id])
    end

    def decoded_variation
      ActiveStorage::Variation.decode(params[:variation_key])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end
end

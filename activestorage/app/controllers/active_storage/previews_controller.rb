# frozen_string_literal: true

class ActiveStorage::PreviewsController < ActionController::Base
  def show
    if blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id])
      expires_in 5.minutes # service_url defaults to 5 minutes
      redirect_to ActiveStorage::Preview.new(blob, params[:variation_key]).processed.service_url(disposition: params[:disposition])
    else
      head :not_found
    end
  end
end

# frozen_string_literal: true

class ActiveStorage::PreviewsController < ActionController::Base
  include ActiveStorage::SetBlob

  def show
    expires_in ActiveStorage::Blob.service.url_expires_in
    redirect_to ActiveStorage::Preview.new(@blob, params[:variation_key]).processed.service_url(disposition: params[:disposition])
  end
end

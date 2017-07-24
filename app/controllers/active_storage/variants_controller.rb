require "active_storage/variant"

class ActiveStorage::VariantsController < ActionController::Base
  def show
    if blob = find_signed_blob
      redirect_to ActiveStorage::Variant.new(blob, decoded_variation).processed.service_url(disposition: disposition_param)
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

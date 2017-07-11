require "action_controller"
require "active_storage/blob"

class ActiveStorage::Controllers::VariantsController < ActionController::Base
  def show
    if blob_key = decode_verified_key
      variant = ActiveStorage::Variant.lookup(blob_key: blob_key, variation_key: params[:variation_key])
      redirect_to variant.url
    else
      head :not_found
    end
  end

  private
    def decode_verified_key
      ActiveStorage::VerifiedKeyWithExpiration.decode(params[:encoded_key])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || 'inline'
    end
end

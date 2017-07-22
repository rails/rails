class ActiveStorage::VariantsController < ActionController::Base
  def show
    if blob_key = decode_verified_blob_key
      redirect_to processed_variant_for(blob_key).url(disposition: disposition_param)
    else
      head :not_found
    end
  end

  private
    def decode_verified_blob_key
      ActiveStorage::VerifiedKeyWithExpiration.decode(params[:encoded_blob_key])
    end

    def processed_variant_for(blob_key)
      ActiveStorage::Variant.new(
        ActiveStorage::Blob.find_by!(key: blob_key),
        ActiveStorage::Variation.decode(params[:variation_key])
      ).processed
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end
end

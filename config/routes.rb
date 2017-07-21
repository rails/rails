Rails.application.routes.draw do
  get  "/rails/active_storage/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_blob
  post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads

  get  "/rails/active_storage/variants/:encoded_blob_key/:variation_key/*filename" => "active_storage/variants#show", as: :rails_blob_variation

  direct :rails_variant do |variant|
    encoded_blob_key = ActiveStorage::VerifiedKeyWithExpiration.encode(variant.blob.key)
    variation_key    = variant.variation.key
    filename         = variant.blob.filename

    route_for(:rails_blob_variation, encoded_blob_key, variation_key, filename)
  end

  resolve 'ActiveStorage::Variant' { |variant| route_for(:rails_variant, variant) }
end

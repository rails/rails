Rails.application.routes.draw do
  get  "/rails/active_storage/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_blob
  get  "/rails/active_storage/variants/:encoded_blob_key/:encoded_variant_key/*filename" => "active_storage/variants#show", as: :rails_blob_variant
  post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads

  resolve 'ActiveStorage::Variant' do |variant|
    encoded_blob_key    = ActiveStorage::VerifiedKeyWithExpiration.encode(variant.blob.key)
    encoded_variant_key = ActiveStorage::Variant.encode_key(variant.variation)
    filename            = variant.blob.filename

    route_for(:rails_blob_variant, encoded_blob_key, encoded_variant_key, filename)
  end
end

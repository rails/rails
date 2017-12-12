# frozen_string_literal: true

Rails.application.routes.draw do
  get "/rails/active_storage/blobs/:signed_id/*filename" => "active_storage/blobs#show", as: :rails_service_blob, internal: true

  direct :rails_blob do |blob, options|
    rails_service_blob_url(blob.signed_id, blob.filename, options)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| rails_blob_url(blob, options) }
  resolve("ActiveStorage::Attachment") { |attachment, options| rails_blob_url(attachment.blob, options) }


  get "/rails/active_storage/variants/:signed_blob_id/:variation_key/*filename" => "active_storage/variants#show", as: :rails_blob_variation, internal: true

  direct :rails_variant do |variant, options|
    signed_blob_id = variant.blob.signed_id
    variation_key  = variant.variation.key
    filename       = variant.blob.filename

    rails_blob_variation_url(signed_blob_id, variation_key, filename, options)
  end

  resolve("ActiveStorage::Variant") { |variant, options| rails_variant_url(variant, options) }


  get "/rails/active_storage/previews/:signed_blob_id/:variation_key/*filename" => "active_storage/previews#show", as: :rails_blob_preview, internal: true

  direct :rails_preview do |preview, options|
    signed_blob_id = preview.blob.signed_id
    variation_key  = preview.variation.key
    filename       = preview.blob.filename

    rails_blob_preview_url(signed_blob_id, variation_key, filename, options)
  end

  resolve("ActiveStorage::Preview") { |preview, options| rails_preview_url(preview, options) }


  get  "/rails/active_storage/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service, internal: true
  put  "/rails/active_storage/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service, internal: true
  post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads, internal: true
end

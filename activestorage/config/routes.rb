# frozen_string_literal: true

Rails.application.routes.draw do
  scope ActiveStorage.routes_prefix do
    get "/blobs/:signed_id/*filename" => "active_storage/blobs#show", as: :rails_service_blob
    get "/blobs_proxy/:signed_id/*filename" => "active_storage/blobs#proxy", as: :rails_blob_proxy

    get "/representations/:signed_blob_id/:variation_key/*filename" => "active_storage/representations#show", as: :rails_blob_representation
    get "/representations_proxy/:signed_blob_id/:variation_key/*filename" => "active_storage/representations#proxy", as: :rails_blob_representation_proxy

    get  "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
    put  "/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service
    post "/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads
  end

  direct :rails_representation do |representation, options|
    ActiveStorage.route_representation(representation, url_options: options)
  end

  resolve("ActiveStorage::Variant") do |variant, options|
    route_for(:rails_representation, variant, options)
  end
  resolve("ActiveStorage::Preview") { |preview, options| route_for(:rails_representation, preview, options) }

  direct :rails_blob do |blob, options|
    ActiveStorage.route_blob(blob.signed_id, blob.filename, options)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| route_for(:rails_blob, blob, options) }
  resolve("ActiveStorage::Attachment") do |attachment, options|
    ActiveStorage.route_blob(
      attachment.blob.signed_id,
      attachment.blob.filename,
      url_options: options,
      delivery_method: attachment&.delivery_method
    )
  end
end

# frozen_string_literal: true

Rails.application.routes.draw do
  scope ActiveStorage.routes_prefix do
    get "/blobs/redirect/:signed_id/*filename" => "active_storage/blobs#show", as: :rails_service_blob
    get "/blobs/proxy/:signed_id/*filename" => "active_storage/blobs#proxy", as: :rails_blob_proxy

    get "/representations/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirection#show", as: :rails_blob_representation
    get "/representations/proxy/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/proxy#show", as: :rails_blob_representation_proxy

    get  "/disk/public/:key/*filename" => "active_storage/public_disk#show", as: :rails_disk_service_public
    get  "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
    put  "/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service
    post "/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads
  end

  direct :rails_representation do |representation, options|
    signed_blob_id = representation.blob.signed_id
    variation_key  = representation.variation.key
    filename       = representation.blob.filename

    route_for(:rails_blob_representation, signed_blob_id, variation_key, filename, options)
  end

  resolve("ActiveStorage::Variant") { |variant, options| route_for(:rails_representation, variant, options) }
  resolve("ActiveStorage::Preview") { |preview, options| route_for(:rails_representation, preview, options) }


  direct :rails_blob do |blob, options|
    route_for(:rails_service_blob, blob.signed_id, blob.filename, options)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| route_for(:rails_blob, blob, options) }
  resolve("ActiveStorage::Attachment") { |attachment, options| route_for(:rails_blob, attachment.blob, options) }
end if ActiveStorage.draw_routes

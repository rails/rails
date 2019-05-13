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

  resolve_delivery_method = -> (attachment) { attachment&.delivery_method || ActiveStorage.delivery_method }

  direct :rails_representation do |representation, options|
    signed_blob_id = representation.blob.signed_id
    variation_key  = representation.variation.key
    filename       = representation.blob.filename

    delivery_method = resolve_delivery_method.(representation.attachment)

    case delivery_method
    when :redirect
      route_for(:rails_blob_representation, signed_blob_id, variation_key, filename, ActiveStorage.url_options(options))
    when :proxy
      route_for(:rails_blob_representation_proxy, signed_blob_id, variation_key, filename, ActiveStorage.url_options(options))
    end
  end

  resolve("ActiveStorage::Variant") do |variant, options|
    route_for(:rails_representation, variant, ActiveStorage.url_options(options))
  end
  resolve("ActiveStorage::Preview") { |preview, options| route_for(:rails_representation, preview, ActiveStorage.url_options(options)) }

  route_blob = -> (blob, delivery_method, options, instance) {
    case delivery_method
    when :redirect
      instance.route_for(:rails_service_blob, blob.signed_id, blob.filename, ActiveStorage.url_options(options))
    when :proxy
      instance.route_for(:rails_blob_proxy, blob.signed_id, blob.filename, ActiveStorage.url_options(options))
    end
  }

  direct :rails_blob do |blob, options|
    route_blob.(blob, ActiveStorage.delivery_method, options, self)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| route_for(:rails_blob, blob, ActiveStorage.url_options(options)) }
  resolve("ActiveStorage::Attachment") do |attachment, options|
    route_blob.(attachment.blob, resolve_delivery_method.(attachment), options, self)
  end
end

# frozen_string_literal: true

Rails.application.routes.draw do
  scope ActiveStorage.routes_prefix do
    get "/blobs/redirect/:signed_id/*filename" => "active_storage/blobs/redirect#show", as: :rails_service_blob
    get "/blobs/proxy/:signed_id/*filename" => "active_storage/blobs/proxy#show", as: :rails_service_blob_proxy
    get "/blobs/:signed_id/*filename" => "active_storage/blobs/redirect#show"

    get "/representations/redirect/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirect#show", as: :rails_blob_representation
    get "/representations/proxy/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/proxy#show", as: :rails_blob_representation_proxy
    get "/representations/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirect#show"

    get  "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
    put  "/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service
    post "/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads
  end

  direct :rails_representation do |representation, options|
    route_for(ActiveStorage.resolve_model_to_route, representation, options)
  end

  resolve("ActiveStorage::Variant") { |variant, options| route_for(ActiveStorage.resolve_model_to_route, variant, options) }
  resolve("ActiveStorage::VariantWithRecord") { |variant, options| route_for(ActiveStorage.resolve_model_to_route, variant, options) }
  resolve("ActiveStorage::Preview") { |preview, options| route_for(ActiveStorage.resolve_model_to_route, preview, options) }

  direct :rails_blob do |blob, options|
    route_for(ActiveStorage.resolve_model_to_route, blob, options)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| route_for(ActiveStorage.resolve_model_to_route, blob, options) }
  resolve("ActiveStorage::Attachment") { |attachment, options| route_for(ActiveStorage.resolve_model_to_route, attachment.blob, options) }

  direct :rails_storage_proxy do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob_proxy,
        model.signed_id(expires_in: expires_in),
        model.filename,
        options
      )
    else
      signed_blob_id = model.blob.signed_id(expires_in: expires_in)
      variation_key  = model.variation.key
      filename       = model.blob.filename

      route_for(
        :rails_blob_representation_proxy,
        signed_blob_id,
        variation_key,
        filename,
        options
      )
    end
  end

  direct :rails_storage_redirect do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob,
        model.signed_id(expires_in: expires_in),
        model.filename,
        options
      )
    else
      signed_blob_id = model.blob.signed_id(expires_in: expires_in)
      variation_key  = model.variation.key
      filename       = model.blob.filename

      route_for(
        :rails_blob_representation,
        signed_blob_id,
        variation_key,
        filename,
        options
      )
    end
  end
end if ActiveStorage.draw_routes

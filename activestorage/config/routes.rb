# frozen_string_literal: true

ActiveStorage::Engine.routes.draw do
  get "/blobs/redirect/:signed_id/*filename" => "blobs/redirect#show", as: :service_blob
  get "/blobs/proxy/:signed_id/*filename" => "blobs/proxy#show", as: :service_blob_proxy
  get "/blobs/:signed_id/*filename" => "blobs/redirect#show"

  get "/representations/redirect/:signed_blob_id/:variation_key/*filename" => "representations/redirect#show", as: :blob_representation
  get "/representations/proxy/:signed_blob_id/:variation_key/*filename" => "representations/proxy#show", as: :blob_representation_proxy
  get "/representations/:signed_blob_id/:variation_key/*filename" => "representations/redirect#show"

  get  "/disk/:encoded_key/*filename" => "disk#show", as: :disk_service
  put  "/disk/:encoded_token" => "disk#update", as: :update_disk_service
  post "/direct_uploads" => "direct_uploads#create", as: :direct_uploads
end

Rails.application.routes.draw do
  direct(:rails_service_blob) {|*args| active_storage.route_for(:service_blob, *args) }
  direct(:rails_service_blob_proxy) {|*args| active_storage.route_for(:service_blob_proxy, *args) }
  direct(:rails_blob_representation) {|*args| active_storage.route_for(:blob_representation, *args) }
  direct(:rails_blob_representation_proxy) {|*args| active_storage.route_for(:blob_representation_proxy, *args) }
  direct(:rails_disk_service) {|*args| active_storage.route_for(:disk_service, *args) }
  direct(:update_rails_disk_service) {|*args| active_storage.route_for(:update_disk_service, *args) }
  direct(:rails_direct_uploads) {|*args| active_storage.route_for(:direct_uploads, *args) }

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
    expires_at = options.delete(:expires_at)

    if model.respond_to?(:signed_id)
      active_storage.route_for(
        :service_blob_proxy,
        model.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.filename,
        options
      )
    else
      signed_blob_id = model.blob.signed_id(expires_in: expires_in, expires_at: expires_at)
      variation_key  = model.variation.key
      filename       = model.blob.filename

      active_storage.route_for(
        :blob_representation_proxy,
        signed_blob_id,
        variation_key,
        filename,
        options
      )
    end
  end

  direct :rails_storage_redirect do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }
    expires_at = options.delete(:expires_at)

    if model.respond_to?(:signed_id)
      active_storage.route_for(
        :service_blob,
        model.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.filename,
        options
      )
    else
      signed_blob_id = model.blob.signed_id(expires_in: expires_in, expires_at: expires_at)
      variation_key  = model.variation.key
      filename       = model.blob.filename

      active_storage.route_for(
        :blob_representation,
        signed_blob_id,
        variation_key,
        filename,
        options
      )
    end
  end
end if ActiveStorage.draw_routes

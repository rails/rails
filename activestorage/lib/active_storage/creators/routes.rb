# frozen_string_literal: true

# = Active Storage \Generators \Models
module ActiveStorage::Creators
  class Routes
    class << self
      def call!
        ActiveStorage.database_configs.each do |db_hash|
          name = db_hash[:name]

          add_routes!(name)
        end
      end

      def resolve_path(name, prefix, type)
        name == :default ? "#{prefix}_#{type}".to_sym : "#{prefix}_#{name}_#{type}".to_sym
      end

      private

      def add_routes!(name)
        prefix = name == :default ? nil : "/#{name}"
        blob_class = name == :default ? "ActiveStorage::Blob" : "ActiveStorage::#{name.to_s.camelize}Blob"
        attachment_class = name == :default ? "ActiveStorage::Attachment" : "ActiveStorage::#{name.to_s.camelize}Attachment"
        variant_record_class = name == :default ? "ActiveStorage::VariantRecord" : "ActiveStorage::#{name.to_s.camelize}VariantRecord"

        klass = self

        Rails.application.routes.append do
          scope ActiveStorage.routes_prefix do
            get "#{prefix}/blobs/redirect/:signed_id/*filename" => "active_storage#{prefix}/blobs/redirect#show",
                as: klass.resolve_path(name, "rails_service", "blob")
            get "#{prefix}/blobs/proxy/:signed_id/*filename" => "active_storage#{prefix}/blobs/proxy#show",
                as: klass.resolve_path(name, "rails_service", "blob_proxy")
            get "#{prefix}/blobs/:signed_id/*filename" => "active_storage#{prefix}/blobs/redirect#show"
        
            get "#{prefix}/representations/redirect/:signed_blob_id/:variation_key/*filename" => "active_storage#{prefix}/representations/redirect#show",
                as: klass.resolve_path(name, "rails", "blob_representation")
            get "#{prefix}/representations/proxy/:signed_blob_id/:variation_key/*filename" => "active_storage#{prefix}/representations/proxy#show",
                as: klass.resolve_path(name, "rails", "blob_representation_proxy")
            get "#{prefix}/representations/:signed_blob_id/:variation_key/*filename" => "active_storage#{prefix}/representations/redirect#show"

            get "#{prefix}/disk/:encoded_key/*filename" => "active_storage#{prefix}/disk#show", as: klass.resolve_path(name, "rails", "disk_service")
            put "#{prefix}/disk/:encoded_token" => "active_storage#{prefix}/disk#update", as: klass.resolve_path(name, "update_rails", "disk_service")
            post "#{prefix}/direct_uploads" => "active_storage#{prefix}/direct_uploads#create", as: klass.resolve_path(name, "rails", "direct_uploads")
          end

          direct klass.resolve_path(name, "rails", "representation") do |representation, options|
            route_for(ActiveStorage.resolve_model_to_route[name], representation, options)
          end
        
          resolve(variant_record_class) { |variant, options| route_for(ActiveStorage.resolve_model_to_route[name], variant, options) }
          resolve("ActiveStorage::VariantWithRecord") { |variant, options| route_for(ActiveStorage.resolve_model_to_route[name], variant, options) }
          resolve("ActiveStorage::Preview") { |preview, options| route_for(ActiveStorage.resolve_model_to_route[name], preview, options) }
        
          direct klass.resolve_path(name, "rails", "blob") do |blob, options|
            route_for(ActiveStorage.resolve_model_to_route[name], blob, options)
          end
        
          resolve(blob_class)       { |blob, options| route_for(ActiveStorage.resolve_model_to_route[name], blob, options) }
          resolve(attachment_class) { |attachment, options| route_for(ActiveStorage.resolve_model_to_route[name], attachment.blob, options) }
        
          direct klass.resolve_path(name, "rails", "storage_proxy") do |model, options|
            expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }
            expires_at = options.delete(:expires_at)
        
            if model.respond_to?(:signed_id)
              route_for(
                klass.resolve_path(name, "rails_service", "blob_proxy"),
                model.signed_id(expires_in: expires_in, expires_at: expires_at),
                model.filename,
                options
              )
            else
              signed_blob_id = model.blob.signed_id(expires_in: expires_in, expires_at: expires_at)
              variation_key  = model.variation.key
              filename       = model.blob.filename
        
              route_for(
                klass.resolve_path(name, "rails", "blob_representation_proxy"),
                signed_blob_id,
                variation_key,
                filename,
                options
              )
            end
          end
        
          direct klass.resolve_path(name, "rails", "storage_redirect") do |model, options|
            expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }
            expires_at = options.delete(:expires_at)
        
            if model.respond_to?(:signed_id)
              route_for(
                klass.resolve_path(name, "rails_service", "blob"),
                model.signed_id(expires_in: expires_in, expires_at: expires_at),
                model.filename,
                options
              )
            else
              signed_blob_id = model.blob.signed_id(expires_in: expires_in, expires_at: expires_at)
              variation_key  = model.variation.key
              filename       = model.blob.filename
        
              route_for(
                klass.resolve_path(name, "rails", "blob_representation"),
                signed_blob_id,
                variation_key,
                filename,
                options
              )
            end
          end
        end
      end
    end
  end
end

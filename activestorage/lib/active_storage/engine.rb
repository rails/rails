# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_job/railtie"
require "active_record/railtie"

require "active_storage"

require "active_storage/previewer/poppler_pdf_previewer"
require "active_storage/previewer/mupdf_previewer"
require "active_storage/previewer/video_previewer"

require "active_storage/analyzer/image_analyzer"
require "active_storage/analyzer/video_analyzer"

require "active_storage/reflection"

module ActiveStorage
  class Engine < Rails::Engine # :nodoc:
    isolate_namespace ActiveStorage

    config.active_storage = ActiveSupport::OrderedOptions.new
    config.active_storage.previewers = [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
    config.active_storage.analyzers = [ ActiveStorage::Analyzer::ImageAnalyzer, ActiveStorage::Analyzer::VideoAnalyzer ]
    config.active_storage.paths = ActiveSupport::OrderedOptions.new
    config.active_storage.queues = ActiveSupport::OrderedOptions.new

    config.active_storage.variable_content_types = %w(
      image/png
      image/gif
      image/jpg
      image/jpeg
      image/pjpeg
      image/tiff
      image/bmp
      image/vnd.adobe.photoshop
      image/vnd.microsoft.icon
    )

    config.active_storage.content_types_to_serve_as_binary = %w(
      text/html
      text/javascript
      image/svg+xml
      application/postscript
      application/x-shockwave-flash
      text/xml
      application/xml
      application/xhtml+xml
      application/mathml+xml
      text/cache-manifest
    )

    config.active_storage.content_types_allowed_inline = %w(
      image/png
      image/gif
      image/jpg
      image/jpeg
      image/tiff
      image/bmp
      image/vnd.adobe.photoshop
      image/vnd.microsoft.icon
      application/pdf
    )

    config.eager_load_namespaces << ActiveStorage

    initializer "active_storage.configs" do
      config.after_initialize do |app|
        ActiveStorage.logger            = app.config.active_storage.logger || Rails.logger
        ActiveStorage.variant_processor = app.config.active_storage.variant_processor || :mini_magick
        ActiveStorage.previewers        = app.config.active_storage.previewers || []
        ActiveStorage.analyzers         = app.config.active_storage.analyzers || []
        ActiveStorage.paths             = app.config.active_storage.paths || {}
        ActiveStorage.routes_prefix     = app.config.active_storage.routes_prefix || "/rails/active_storage"

        ActiveStorage.variable_content_types = app.config.active_storage.variable_content_types || []
        ActiveStorage.content_types_to_serve_as_binary = app.config.active_storage.content_types_to_serve_as_binary || []
        ActiveStorage.service_urls_expire_in = app.config.active_storage.service_urls_expire_in || 5.minutes
        ActiveStorage.content_types_allowed_inline = app.config.active_storage.content_types_allowed_inline || []
        ActiveStorage.binary_content_type = app.config.active_storage.binary_content_type || "application/octet-stream"

        ActiveStorage.replace_on_assign_to_many = app.config.active_storage.replace_on_assign_to_many || false
      end
    end

    initializer "active_storage.attached" do
      require "active_storage/attached"

      ActiveSupport.on_load(:active_record) do
        include ActiveStorage::Attached::Model
      end
    end

    initializer "active_storage.verifier" do
      config.after_initialize do |app|
        ActiveStorage.verifier = app.message_verifier("ActiveStorage")
      end
    end

    initializer "active_storage.services" do
      ActiveSupport.on_load(:active_storage_blob) do
        if config_choice = Rails.configuration.active_storage.service
          ActiveStorage::Blob.service = ActiveStorage::ServiceRegistry.fetch(config_choice) do
            raise ArgumentError, "Cannot load `Rails.application.config.active_storage.service`:\n#{config_choice}"
          end
        end
      end
    end

    initializer "active_storage.queues" do
      config.after_initialize do |app|
        if queue = app.config.active_storage.queue
          ActiveSupport::Deprecation.warn \
            "config.active_storage.queue is deprecated and will be removed in Rails 6.1. " \
            "Set config.active_storage.queues.purge and config.active_storage.queues.analysis instead."

          ActiveStorage.queues = { purge: queue, analysis: queue }
        else
          ActiveStorage.queues = app.config.active_storage.queues || {}
        end
      end
    end

    initializer "active_storage.reflection" do
      ActiveSupport.on_load(:active_record) do
        include Reflection::ActiveRecordExtensions
        ActiveRecord::Reflection.singleton_class.prepend(Reflection::ReflectionExtension)
      end
    end
  end
end

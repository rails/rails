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
require "active_storage/analyzer/image_analyzer/image_magick"
require "active_storage/analyzer/image_analyzer/vips"
require "active_storage/analyzer/video_analyzer"
require "active_storage/analyzer/audio_analyzer"

require "active_storage/service/registry"

require "active_storage/reflection"

module ActiveStorage
  class Engine < Rails::Engine # :nodoc:
    isolate_namespace ActiveStorage

    config.active_storage = ActiveSupport::OrderedOptions.new
    config.active_storage.previewers = [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
    config.active_storage.analyzers = [ ActiveStorage::Analyzer::ImageAnalyzer::Vips, ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick, ActiveStorage::Analyzer::VideoAnalyzer, ActiveStorage::Analyzer::AudioAnalyzer ]
    config.active_storage.paths = ActiveSupport::OrderedOptions.new
    config.active_storage.queues = ActiveSupport::InheritableOptions.new

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
      image/webp
      image/avif
      image/heic
      image/heif
    )

    config.active_storage.web_image_content_types = %w(
      image/png
      image/jpeg
      image/jpg
      image/gif
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
        ActiveStorage.draw_routes       = app.config.active_storage.draw_routes != false
        ActiveStorage.resolve_model_to_route = app.config.active_storage.resolve_model_to_route || :rails_storage_redirect

        ActiveStorage.variable_content_types = app.config.active_storage.variable_content_types || []
        ActiveStorage.web_image_content_types = app.config.active_storage.web_image_content_types || []
        ActiveStorage.content_types_to_serve_as_binary = app.config.active_storage.content_types_to_serve_as_binary || []
        ActiveStorage.service_urls_expire_in = app.config.active_storage.service_urls_expire_in || 5.minutes
        ActiveStorage.urls_expire_in = app.config.active_storage.urls_expire_in
        ActiveStorage.content_types_allowed_inline = app.config.active_storage.content_types_allowed_inline || []
        ActiveStorage.binary_content_type = app.config.active_storage.binary_content_type || "application/octet-stream"
        ActiveStorage.video_preview_arguments = app.config.active_storage.video_preview_arguments || "-y -vframes 1 -f image2"

        ActiveStorage.silence_invalid_content_types_warning = app.config.active_storage.silence_invalid_content_types_warning || false

        ActiveStorage.replace_on_assign_to_many = app.config.active_storage.replace_on_assign_to_many || false
        ActiveStorage.track_variants = app.config.active_storage.track_variants || false
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
        configs = Rails.configuration.active_storage.service_configurations ||=
          begin
            config_file = Rails.root.join("config/storage/#{Rails.env}.yml")
            config_file = Rails.root.join("config/storage.yml") unless config_file.exist?
            raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

            ActiveSupport::ConfigurationFile.parse(config_file)
          end

        ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(configs)

        if config_choice = Rails.configuration.active_storage.service
          ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(config_choice)
        end
      end
    end

    initializer "active_storage.queues" do
      config.after_initialize do |app|
        ActiveStorage.queues = app.config.active_storage.queues || {}
      end
    end

    initializer "active_storage.reflection" do
      ActiveSupport.on_load(:active_record) do
        include Reflection::ActiveRecordExtensions
        ActiveRecord::Reflection.singleton_class.prepend(Reflection::ReflectionExtension)
      end
    end

    initializer "action_view.configuration" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:action_view) do
          multiple_file_field_include_hidden = app.config.active_storage.delete(:multiple_file_field_include_hidden)

          unless multiple_file_field_include_hidden.nil?
            ActionView::Helpers::FormHelper.multiple_file_field_include_hidden = multiple_file_field_include_hidden
          end
        end
      end
    end

    initializer "active_storage.asset" do
      if Rails.application.config.respond_to?(:assets)
        Rails.application.config.assets.precompile += %w( activestorage activestorage.esm )
      end
    end

    initializer "active_storage.fixture_set" do
      ActiveSupport.on_load(:active_record_fixture_set) do
        ActiveStorage::FixtureSet.file_fixture_path ||= Rails.root.join(*[
          ENV.fetch("FIXTURES_PATH") { File.join("test", "fixtures") },
          ENV["FIXTURES_DIR"],
          "files"
        ].compact_blank)
      end

      ActiveSupport.on_load(:active_support_test_case) do
        ActiveStorage::FixtureSet.file_fixture_path = ActiveSupport::TestCase.file_fixture_path
      end
    end
  end
end

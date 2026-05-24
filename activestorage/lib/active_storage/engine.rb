# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_job/railtie"

require "active_storage"

require "active_storage/previewer/poppler_pdf_previewer"
require "active_storage/previewer/mupdf_previewer"
require "active_storage/previewer/video_previewer"

require "active_storage/analyzer/image_analyzer"
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
    config.active_storage.precompile_assets = true
    config.active_storage.blob_class = "ActiveStorage::Blob"
    config.active_storage.attachment_class = "ActiveStorage::Attachment"
    config.active_storage.variant_record_class = "ActiveStorage::VariantRecord"

    config.active_storage.variable_content_types = %w(
      image/png
      image/gif
      image/jpeg
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
      image/gif
    )

    config.active_storage.content_types_to_serve_as_binary = %w(
      text/html
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
      image/webp
      image/avif
      image/png
      image/gif
      image/jpeg
      image/tiff
      image/bmp
      image/vnd.adobe.photoshop
      image/vnd.microsoft.icon
      application/pdf
    )

    config.eager_load_namespaces << ActiveStorage

    guard_load_hooks(:active_storage_record, :active_storage_attachment, :active_storage_blob, :active_storage_variant_record)

    initializer "active_storage.deprecator", before: :load_environment_config do |app|
      app.deprecators[:active_storage] = ActiveStorage.deprecator
    end

    initializer "active_storage.configs" do
      config.before_initialize do |app|
        ActiveStorage.touch_attachment_records = app.config.active_storage.touch_attachment_records != false
      end

      config.after_initialize do |app|
        ActiveStorage.logger            = app.config.active_storage.logger || Rails.logger
        ActiveStorage.variant_processor = app.config.active_storage.variant_processor || :mini_magick
        ActiveStorage.previewers        = app.config.active_storage.previewers || []
        ActiveStorage.analyzers         = app.config.active_storage.analyzers || []

        begin
          ActiveStorage.variant_transformer =
            case ActiveStorage.variant_processor
            when :disabled
              ActiveStorage::Transformers::NullTransformer
            when :vips
              ActiveStorage::Transformers::Vips
            when :mini_magick
              ActiveStorage::Transformers::ImageMagick
            end
        rescue LoadError => error
          case error.message
          when /libvips/
            ActiveStorage.logger.warn <<~WARNING.squish
              Using vips to process variants requires the libvips library.
              Please install libvips using the instructions on the libvips website.
            WARNING
          when /image_processing/
            ActiveStorage.logger.warn <<~WARNING.squish
              Generating image variants require the image_processing gem.
              Please add `gem "image_processing", "~> 2.0"` to your Gemfile
              or set `config.active_storage.variant_processor = :disabled`.
            WARNING
          when /ruby-vips/
            ActiveStorage.logger.warn <<~WARNING.squish
              Generating image variants with libvips requires the ruby-vips gem.
              Please add `gem "ruby-vips", "~> 2.3"` to your Gemfile.
            WARNING
          when /mini_magick/
            ActiveStorage.logger.warn <<~WARNING.squish
              Generating image variants with ImageMagick requires the mini_magick gem.
              Please add `gem "mini_magick", "~> 5.0"` to your Gemfile.
            WARNING
          else
            raise
          end
        end

        ActiveStorage.paths             = app.config.active_storage.paths || {}
        ActiveStorage.routes_prefix     = app.config.active_storage.routes_prefix || "/rails/active_storage"
        ActiveStorage.draw_routes       = app.config.active_storage.draw_routes != false
        ActiveStorage.resolve_model_to_route = app.config.active_storage.resolve_model_to_route || :rails_storage_redirect

        ActiveStorage.base_controller_parent = app.config.active_storage.base_controller_parent ||
          if app.config.api_only
            "::ActionController::API"
          else
            "::ActionController::Base"
          end

        ActiveStorage.supported_image_processing_methods += app.config.active_storage.supported_image_processing_methods || []
        ActiveStorage.unsupported_image_processing_arguments = app.config.active_storage.unsupported_image_processing_arguments || %w(
          -debug
          -display
          -distribute-cache
          -help
          -path
          -print
          -set
          -verbose
          -version
          -write
          -write-mask
        )

        ActiveStorage.variable_content_types = app.config.active_storage.variable_content_types || []
        ActiveStorage.web_image_content_types = app.config.active_storage.web_image_content_types || []
        ActiveStorage.content_types_to_serve_as_binary = app.config.active_storage.content_types_to_serve_as_binary || []
        ActiveStorage.service_urls_expire_in = app.config.active_storage.service_urls_expire_in || 5.minutes
        ActiveStorage.urls_expire_in = app.config.active_storage.urls_expire_in
        ActiveStorage.content_types_allowed_inline = app.config.active_storage.content_types_allowed_inline || []
        ActiveStorage.binary_content_type = app.config.active_storage.binary_content_type || "application/octet-stream"
        ActiveStorage.video_preview_arguments = app.config.active_storage.video_preview_arguments || "-y -vframes 1 -f image2"
        ActiveStorage.track_variants = app.config.active_storage.track_variants || false
        ActiveStorage.analyze = app.config.active_storage.analyze || :later
        ActiveStorage.streaming_chunk_max_size = app.config.active_storage.streaming_chunk_max_size || 100.megabytes
      end
    end

    initializer "active_storage.attached" do
      require "active_storage/attached"

      ActiveSupport.on_load(:active_record) do
        require "active_storage/active_record_models"
      end
    end

    initializer "active_storage.class_indirection" do |app|
      ActiveStorage.blob_class = app.config.active_storage.blob_class
      ActiveStorage.attachment_class = app.config.active_storage.attachment_class
      ActiveStorage.variant_record_class = app.config.active_storage.variant_record_class
    end

    # Rails engines automatically register app/models for eager loading, and the
    # default Active Storage backend ships its blob/attachment/variant_record
    # models there. A boot without Active Record -- or one that swaps in a custom
    # storage backend -- must remove those Active Record model files from Zeitwerk
    # before the main autoloader is set up, otherwise eager loading pulls them in.
    # Declared after "active_storage.class_indirection" so a backend gem's class
    # config (set from its Railtie before that initializer, as the guide
    # recommends) is visible here, and before :setup_main_autoloader so the
    # ignores take effect.
    initializer "active_storage.zeitwerk_ignore_when_no_active_record", after: "active_storage.class_indirection", before: :setup_main_autoloader do |app|
      custom_storage_configured =
        app.config.active_storage.blob_class != "ActiveStorage::Blob" ||
        app.config.active_storage.attachment_class != "ActiveStorage::Attachment" ||
        app.config.active_storage.variant_record_class != "ActiveStorage::VariantRecord"

      if !defined?(::ActiveRecord::Base) || custom_storage_configured
        ar_paths = [
          "app/models/active_storage/record.rb",
          "app/models/active_storage/blob.rb",
          "app/models/active_storage/attachment.rb",
          "app/models/active_storage/variant_record.rb",
          "app/models/active_storage/blob",
        ]

        ar_paths.each do |relative_path|
          path = File.expand_path("../../#{relative_path}", __dir__)
          Rails.autoloaders.main.ignore(path) if File.exist?(path)
        end
      end
    end

    initializer "active_storage.class_indirection_reloader" do |app|
      app.reloader.to_prepare do
        ActiveStorage.clear_class_indirection_cache
      end
    end

    initializer "active_storage.validate_class_configuration", after: "active_storage.class_indirection" do
      validate_classes = lambda do |*|
        required = {
          "blob_class" => ActiveStorage.class_variable_get(:@@blob_class),
          "attachment_class" => ActiveStorage.class_variable_get(:@@attachment_class),
          "variant_record_class" => ActiveStorage.class_variable_get(:@@variant_record_class),
        }

        defaults = {
          "blob_class" => "ActiveStorage::Blob",
          "attachment_class" => "ActiveStorage::Attachment",
          "variant_record_class" => "ActiveStorage::VariantRecord",
        }

        required.each do |slot, name|
          next if name == defaults[slot]

          unless name.safe_constantize
            raise ActiveStorage::ConfigurationError,
              "config.active_storage.#{slot} = #{name.inspect} but that constant is not defined. " \
              "Ensure the third-party gem providing the class is required and its constant is loadable."
          end
        end

        any_default = required.any? { |slot, value| value == defaults[slot] }
        any_custom = required.any? { |slot, value| value != defaults[slot] }

        if any_default && any_custom
          raise ActiveStorage::ConfigurationError, "Partial custom storage configuration: ALL of blob_class/attachment_class/variant_record_class must be customized together, or all left default."
        end

        if any_default && !defined?(::ActiveRecord::Base)
          missing = required.select { |_, value| value.to_s.start_with?("ActiveStorage::") }.keys
          raise ActiveStorage::ConfigurationError, <<~MSG
            ActiveStorage is configured to use the default class names (#{missing.join(", ")})
            but ActiveRecord is not loaded. Either:
              1. Add `gem "activerecord"` to your Gemfile, or
              2. Configure custom backend classes for all three slots:
                   config.active_storage.blob_class           = "MyBlob"
                   config.active_storage.attachment_class     = "MyAttachment"
                   config.active_storage.variant_record_class = "MyVariantRecord"
          MSG
        end
      end

      config.before_eager_load(&validate_classes)
      config.after_initialize(&validate_classes)
    end

    initializer "active_storage.verifier" do
      config.after_initialize do |app|
        ActiveStorage.verifier = app.message_verifier("ActiveStorage")
      end
    end

    initializer "active_storage.services" do |app|
      ActiveSupport.on_load(:active_storage_blob) do
        ActiveStorage::Services.setup_from_app_config(app)
      end
    end

    initializer "active_storage.queues" do
      config.after_initialize do |app|
        ActiveStorage.queues = app.config.active_storage.queues || {}
      end
    end

    initializer "action_view.configuration" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:action_view) do
          multiple_file_field_include_hidden = app.config.active_storage.multiple_file_field_include_hidden

          unless multiple_file_field_include_hidden.nil?
            ActionView::Helpers::FormHelper.multiple_file_field_include_hidden = multiple_file_field_include_hidden
          end
        end
      end
    end

    initializer "active_storage.asset" do
      config.after_initialize do |app|
        if app.config.respond_to?(:assets) && app.config.active_storage.precompile_assets
          app.config.assets.precompile += %w( activestorage activestorage.esm )
        end
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
        if defined?(::ActiveRecord::Base)
          ActiveStorage::FixtureSet.file_fixture_path = ActiveSupport::TestCase.file_fixture_path
        end
      end
    end

    initializer "active_storage.action_dispatch_rescue_responses", before: "action_dispatch.configure" do |app|
      app.config.action_dispatch.rescue_responses.merge!(
        "ActiveStorage::RecordNotFound" => :not_found,
        "ActiveStorage::RecordInvalid" => ActionDispatch::Constants::UNPROCESSABLE_CONTENT,
        "ActiveStorage::RecordNotSaved" => ActionDispatch::Constants::UNPROCESSABLE_CONTENT,
      )
    end
  end
end

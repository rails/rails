# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_storage"
require "open3"

module ApplicationTests
  class ActiveStorageWithActiveRecordTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      reset_environment_configs
      use_active_record_with_custom_storage_backend
    end

    def teardown
      teardown_app
    end

    # Regression: with Active Record loaded and a backend gem configuring custom
    # storage classes from its Railtie (before "active_storage.class_indirection",
    # as the guide recommends), the default Active Storage Active Record models
    # must be ignored before eager loading. Otherwise they eager-load, declare
    # their internal attachments (VariantRecord#image, Blob#preview_image), and
    # trip HybridConfigurationError. The classes are set from an initializer --
    # not config/application.rb -- so the ignore pass only sees them if it runs
    # after the backend Railtie has configured them.
    test "boots with active record and a custom backend railtie when eager loading" do
      add_to_config <<~RUBY
        config.eager_load = true

        initializer "custom_backend.active_storage", before: "active_storage.class_indirection" do |app|
          app.config.active_storage.blob_class = "CustomActiveStorageBlob"
          app.config.active_storage.attachment_class = "CustomActiveStorageAttachment"
          app.config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
        end
      RUBY

      output = rails_runner <<~RUBY
        puts(defined?(::ActiveRecord::Base) ? "ar_loaded" : "no_ar")
        puts ActiveStorage.blob_class.name
        puts ActiveStorage::Attached::Builder.declared_classes.select { |owner| ActiveStorage::Attached::Builder.active_record_owner?(owner) }.map(&:name).inspect
      RUBY

      assert_equal [ "ar_loaded", "CustomActiveStorageBlob", "[]" ], output.lines.map(&:chomp).last(3)
    end

    test "loads active record automatically with manually listed frameworks" do
      application = File.read(app_path("config/application.rb"))
      application.sub!('require "active_record/railtie"', "")
      app_file "config/application.rb", application

      output = rails_runner <<~RUBY
        Rails.application.reload_routes!
        puts ActiveStorage.blob_class.name
        puts ActiveStorage::Blob.superclass.name
      RUBY

      assert_equal [ "ActiveStorage::Blob", "ActiveStorage::Record" ], output.lines.map(&:chomp).last(2)
    end

    test "accepts default storage class objects without ignoring the remaining default models" do
      add_to_config <<~RUBY
        config.eager_load = true
        config.active_storage.service = :local
      RUBY
      app_file "config/initializers/active_storage.rb", <<~RUBY
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/app/models/active_storage/record").inspect}
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/app/models/active_storage/attachment").inspect}
        Rails.application.config.active_storage.attachment_class = ActiveStorage::Attachment
      RUBY

      output = rails_runner <<~RUBY
        puts ActiveStorage.blob_class.name
        puts ActiveStorage.attachment_class.name
        puts ActiveStorage.variant_record_class.name
      RUBY

      assert_equal [ "ActiveStorage::Blob", "ActiveStorage::Attachment", "ActiveStorage::VariantRecord" ], output.lines.map(&:chomp).last(3)
    end

    test "configures the reloaded blob service when eager loading" do
      add_to_config <<~RUBY
        config.eager_load = true
        config.enable_reloading = true
        config.active_storage.service = :local
      RUBY

      output = rails_runner <<~RUBY
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/db/migrate/20170806125915_create_active_storage_tables").inspect}
        ActiveRecord::Migration.verbose = false
        CreateActiveStorageTables.new.change
        previous = ActiveStorage.blob_class
        Rails.application.reloader.reload!
        raise "blob class was not reloaded" if ActiveStorage.blob_class.equal?(previous)
        blob = ActiveStorage.blob_class.create_and_upload!(io: StringIO.new("hello"), filename: "hello.txt")
        puts blob.download
        blob.purge
      RUBY

      assert_equal "hello", output.lines.last.chomp
    end

    test "validating reloaded storage classes does not autoload attachment owners" do
      add_to_config <<~RUBY
        config.eager_load = false
        config.enable_reloading = true
        config.active_storage.service = :local
      RUBY
      app_file "app/models/user.rb", <<~RUBY
        class User < ApplicationRecord
          has_one_attached :avatar
        end
      RUBY
      app_file "app/models/gallery/picture.rb", <<~RUBY
        class Gallery::Picture < ApplicationRecord
          has_one_attached :image
        end
      RUBY

      output = rails_runner <<~RUBY
        previous = [User, Gallery::Picture]
        Rails.application.reloader.reload!
        raise "validation loaded User" unless Object.autoload?(:User)
        raise "validation loaded Gallery" unless Object.autoload?(:Gallery)

        namespace = Gallery
        ActiveStorage::Blob
        raise "service setup loaded User" unless Object.autoload?(:User)
        raise "service setup loaded Picture" unless namespace.autoload?(:Picture)

        current = [User, Gallery::Picture]
        owners = ActiveStorage::Attached::Builder.declared_classes
        raise "registry retained old owners" if previous.any? { |owner| owners.include?(owner) }
        raise "registry missed current owners" unless current.all? { |owner| owners.include?(owner) }
        puts "owners loaded on demand"
      RUBY

      assert_equal "owners loaded on demand", output.lines.last.chomp
    end

    test "validates services when attachment owners load after reloading" do
      add_to_config <<~RUBY
        config.eager_load = false
        config.enable_reloading = true
        config.active_storage.service = :local
        config.x.avatar_service = :local
      RUBY
      app_file "app/models/user.rb", <<~RUBY
        class User < ApplicationRecord
          has_one_attached :avatar, service: Rails.configuration.x.avatar_service
        end
      RUBY

      output = rails_runner <<~RUBY
        User
        Rails.configuration.x.avatar_service = :missing
        Rails.application.reloader.reload!
        begin
          User
        rescue ArgumentError => error
          puts error.message
        end
      RUBY

      assert_equal "Cannot configure service :missing for User#avatar", output.lines.last.chomp
    end

    test "configures services on reloaded custom blob classes" do
      add_to_top_of_config <<~RUBY
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_storage/in_memory_backend").inspect}
      RUBY
      app_file "app/models/reloadable_blob.rb", <<~RUBY
        class ReloadableBlob < ActiveStorage::InMemoryBackend::Blob
          class << self
            attr_accessor :services, :service
          end
        end
      RUBY
      add_to_config <<~RUBY
        config.eager_load = true
        config.enable_reloading = true
        config.active_storage.service = :local
        config.active_storage.blob_class = "ReloadableBlob"
        config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
        config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"
        initializer "custom_backend.services", after: :setup_main_autoloader do |app|
          ActiveStorage::Services.setup_from_app_config(app)
        end
      RUBY

      output = rails_runner <<~RUBY
        previous = ActiveStorage.blob_class
        raise "initial service missing" unless previous.service
        Rails.application.reloader.reload!
        raise "class was not reloaded" if ActiveStorage.blob_class.equal?(previous)
        blob = ActiveStorage.blob_class.create_and_upload!(io: StringIO.new("hello"), filename: "hello.txt")
        puts blob.download
      RUBY

      assert_equal "hello", output.lines.last.chomp
    end

    test "reads custom class configuration from application initializers" do
      app_file "config/initializers/active_storage.rb", <<~RUBY
        Rails.application.config.active_storage.blob_class = "CustomActiveStorageBlob"
        Rails.application.config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        Rails.application.config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
      RUBY

      assert_equal "CustomActiveStorageBlob", rails_runner("puts ActiveStorage.blob_class.name").lines.last.chomp
    end

    test "rejects partial custom class configuration before resolving models" do
      add_to_config 'config.active_storage.blob_class = "MissingBackendBlob"'

      output = rails_runner("puts 'booted'", allow_failure: true)

      assert_includes output, "Partial custom storage configuration"
    end

    test "reports an undefined custom backend class during boot" do
      add_to_config <<~RUBY
        config.active_storage.blob_class = "MissingBackendBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
      RUBY

      output = rails_runner("puts 'booted'", allow_failure: true)

      assert_includes output, 'config.active_storage.blob_class = "MissingBackendBlob" but that constant is not defined'
    end

    test "reports an undefined blob class from the backend service initializer" do
      add_to_config <<~RUBY
        config.active_storage.service = :local
        config.active_storage.blob_class = "MissingBackendBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
        initializer "custom_backend.services", after: :setup_main_autoloader do |app|
          ActiveStorage::Services.setup_from_app_config(app)
        end
      RUBY

      output = rails_runner("puts 'booted'", allow_failure: true)

      assert_includes output, 'config.active_storage.blob_class = "MissingBackendBlob" but that constant is not defined'
      assert_includes output, "ActiveStorage::ConfigurationError"
    end

    test "reports an undefined blob class when reloading configured backend services" do
      add_to_config <<~RUBY
        config.enable_reloading = true
        config.active_storage.service = :local
        config.active_storage.blob_class = "CustomActiveStorageBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
        initializer "custom_backend.services", after: :setup_main_autoloader do |app|
          ActiveStorage::Services.setup_from_app_config(app)
        end
      RUBY

      output = rails_runner <<~RUBY
        ActiveStorage.blob_class = "MissingBackendBlob"
        begin
          Rails.application.reloader.reload!
        rescue ActiveStorage::ConfigurationError => error
          puts error.message
        end
      RUBY

      assert_includes output, 'config.active_storage.blob_class = "MissingBackendBlob" but that constant is not defined'
    end

    test "preserves errors raised while loading a configured backend class" do
      app_file "app/models/broken_backend_blob.rb", <<~RUBY
        class BrokenBackendBlob
          MissingBackendDependency
        end
      RUBY
      add_to_config <<~RUBY
        config.active_storage.service = :local
        config.active_storage.blob_class = "BrokenBackendBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
        initializer "custom_backend.services", after: :setup_main_autoloader do |app|
          ActiveStorage::Services.setup_from_app_config(app)
        end
      RUBY

      output = rails_runner("puts 'booted'", allow_failure: true)

      assert_includes output, "MissingBackendDependency"
      assert_includes output, "NameError"
      assert_not_includes output, "ActiveStorage::ConfigurationError"
    end

    test "backend gems can declare attachments before the application class exists" do
      application = File.read(app_path("config/application.rb"))
      application.sub!('require "active_storage/engine"', <<~RUBY)
        require "active_storage/engine"
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_storage/in_memory_backend").inspect}
        ActiveStorage::InMemoryBackend.install
      RUBY
      app_file "config/application.rb", application
      add_to_config <<~RUBY
        config.eager_load = true
        config.active_storage.service = :local
        initializer "custom_backend.configuration", before: "active_storage.class_indirection" do |app|
          app.config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
          app.config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
          app.config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"
        end
        initializer "custom_backend.services", after: "active_storage.class_indirection" do |app|
          ActiveStorage::Services.setup_from_app_config(app)
        end
      RUBY

      output = rails_runner <<~RUBY
        blob = ActiveStorage.blob_class.create_and_upload!(io: StringIO.new("original"), filename: "original.txt")
        blob.preview_image.attach(io: StringIO.new("preview"), filename: "preview.txt")
        puts blob.preview_image.download
      RUBY

      assert_equal "preview", output.lines.last.chomp
    end

    test "custom backend attaches without a database configuration when active record is available" do
      FileUtils.rm_f app_path("config/database.yml")
      add_to_config <<~RUBY
        config.active_storage.service = :local
        config.active_storage.service_configurations = {
          local: { service: "Disk", root: Rails.root.join("tmp/storage") }
        }
        config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
        config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
        config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"

        initializer "custom_backend.models", before: "active_storage.class_indirection" do
          require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_storage/in_memory_backend").inspect}
          require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_model_owner").inspect}
        end

        initializer "custom_backend.install", after: "active_storage.class_indirection" do |app|
          ActiveStorage::Services.setup_from_app_config(app)
          ActiveStorage::InMemoryBackend.install
        end
      RUBY

      script = <<~RUBY
        owner = ActiveStorage::ActiveModelOwnerFixture.define!.new(name: "Dorian")
        owner.avatar.attach(io: StringIO.new("hello"), filename: "hello.txt")
        owner.save!
        puts owner.avatar.blob.send(:with_writing_role) { owner.avatar.download }
      RUBY

      output, status = Open3.capture2e(Gem.ruby, "-r", "./config/environment", "-e", script, chdir: app_path)
      assert_predicate status, :success?, output
      assert_equal "hello", output.lines.last.chomp
    end

    ["bare", "active_model", "renamed_active_model"].each do |naming|
      test "resolves ordinary helpers for #{naming} backend classes after route reloads" do
        add_to_config <<~RUBY
          config.active_storage.blob_class = "CustomActiveStorageBlob"
          config.active_storage.attachment_class = "CustomActiveStorageAttachment"
          config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
        RUBY
        add_to_top_of_config <<~RUBY
          class ::CustomActiveStorageBlob
            include ActiveStorage::Servable
            def signed_id(**) = "signed-blob"
            def filename = ActiveStorage::Filename.new("hello.txt")
          end

          class ::CustomActiveStorageAttachment
            def blob = CustomActiveStorageBlob.new
          end

          initializer "custom_backend.naming", before: "active_storage.class_indirection" do
            unless #{naming.inspect} == "bare"
              [CustomActiveStorageBlob, CustomActiveStorageAttachment].each do |model|
                model.include ActiveModel::Model
                if #{naming.inspect} == "renamed_active_model"
                  model.define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Named" + name) }
                end
              end
            end
          end
        RUBY

        output = rails_runner <<~RUBY
          Rails.application.routes.default_url_options[:host] = "example.org"
          controller = ApplicationController.new
          controller.set_request!(ActionDispatch::Request.new(Rack::MockRequest.env_for("http://example.org")))
          view = controller.view_context
          [:redirect, :proxy].each do |mode|
            ActiveStorage.resolve_model_to_route = :"rails_storage_\#{mode}"
            Rails.application.reload_routes!
            blob = CustomActiveStorageBlob.new
            attachment = CustomActiveStorageAttachment.new
            owner = Struct.new(:avatar_attachment, :attachment_changes).new(attachment, {})
            avatar = ActiveStorage::Attached::One.new("avatar", owner)
            expected = "/rails/active_storage/blobs/\#{mode}/signed-blob/hello.txt"
            raise "blob URL mismatch: \#{view.url_for(blob)}" unless view.url_for(blob) == expected
            raise "attachment URL mismatch: \#{view.url_for(attachment)}" unless view.url_for(attachment) == expected
            raise "image URL mismatch" unless view.image_tag(attachment).include?(expected)
            raise "attachment proxy URL mismatch" unless view.image_tag(avatar).include?(expected)
            raise "absolute URL mismatch" unless view.polymorphic_url(blob) == "http://example.org" + expected
          end
          puts "resolved"
        RUBY

        assert_equal "resolved", output.lines.last.chomp
      end
    end

    private
      def rails_runner(script, allow_failure: false)
        with_env("NO_FORK" => "1") do
          rails [ "runner", script ], allow_failure: allow_failure
        end
      end

      # Boots Active Record (so ActiveRecord::Base is defined) but leaves out the
      # frameworks whose Active Record models declare attachments (Action Text,
      # Action Mailbox), modelling an app that pairs Active Record domain models
      # with a custom, non-Active Record storage backend. Defines the custom
      # storage classes inline so the configuration validator can constantize
      # them.
      def use_active_record_with_custom_storage_backend
        FileUtils.rm_rf "#{app_path}/app/channels"
        FileUtils.rm_rf "#{app_path}/app/mailers"

        boot = File.read("#{app_path}/config/boot.rb")
        boot.gsub!("\nrequire \"rails/all\"", "")
        File.write("#{app_path}/config/boot.rb", boot)

        application = File.read("#{app_path}/config/application.rb")
        application.gsub! <<~RUBY.strip, <<~RUBY.strip
          require "rails/all"
        RUBY
          require "rails"
          require "active_model/railtie"
          require "active_record/railtie"
          require "active_job/railtie"
          require "action_controller/railtie"
          require "active_storage/engine"
        RUBY
        application.sub!(/^(module .*)$/, <<~RUBY.chomp + "\n\\1")
          class CustomActiveStorageBlob; end
          class CustomActiveStorageAttachment; end
          class CustomActiveStorageVariantRecord; end
        RUBY
        File.write("#{app_path}/config/application.rb", application)
      end
  end
end

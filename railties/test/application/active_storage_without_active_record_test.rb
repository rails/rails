# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_storage"
require "open3"

module ApplicationTests
  class ActiveStorageWithoutActiveRecordTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      reset_environment_configs
      use_active_storage_without_active_record
    end

    def teardown
      teardown_app
    end

    test "raises a clear error when default storage classes are used without active record" do
      output = rails_runner("puts 'booted'", allow_failure: true)

      assert_match "ActiveStorage is configured to use the default class names", output
      assert_match "config.active_storage.blob_class", output
    end

    test "loads the default backend when active record is explicitly added to the bundle" do
      app_file "Gemfile", <<~RUBY, "a"
        gem "activerecord", path: #{File.join(RAILS_FRAMEWORK_ROOT, "activerecord").inspect}
        gem "sqlite3"
      RUBY
      output, status = isolated_command(Gem.ruby, Gem.bin_path("bundler", "bundle"), "lock", "--local")
      assert_predicate status, :success?, output
      add_to_config "config.active_storage.service = :local"

      output = rails_runner <<~RUBY
        Rails.application.reload_routes!
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/db/migrate/20170806125915_create_active_storage_tables").inspect}
        ActiveRecord::Migration.verbose = false
        CreateActiveStorageTables.new.change
        puts ActiveStorage.blob_class.name
        puts ActiveStorage.blob_class < ActiveRecord::Base
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hello"), filename: "hello.txt")
        puts blob.download
        blob.purge
      RUBY

      assert_equal [ "ActiveStorage::Blob", "true", "hello" ], output.lines.map(&:chomp).last(3)
    end

    test "boots without active record when custom storage classes are configured" do
      define_custom_storage_classes
      add_to_config <<~RUBY
        config.active_storage.blob_class = "CustomActiveStorageBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
      RUBY

      output = rails_runner <<~RUBY
        puts defined?(::ActiveRecord::Base).inspect
        puts ActiveStorage.blob_class.name
        puts ActiveStorage.attachment_class.name
        puts ActiveStorage.variant_record_class.name
      RUBY

      assert_equal [
        "nil",
        "CustomActiveStorageBlob",
        "CustomActiveStorageAttachment",
        "CustomActiveStorageVariantRecord"
      ], output.lines.map(&:chomp).last(4)
    end

    test "eager loads without active record when custom storage classes are configured" do
      define_custom_storage_classes
      add_to_config <<~RUBY
        config.eager_load = true
        config.active_storage.blob_class = "CustomActiveStorageBlob"
        config.active_storage.attachment_class = "CustomActiveStorageAttachment"
        config.active_storage.variant_record_class = "CustomActiveStorageVariantRecord"
      RUBY

      output = rails_runner <<~RUBY
        puts defined?(::ActiveRecord::Base).inspect
        puts ActiveStorage.blob_class.name
      RUBY

      assert_equal [ "nil", "CustomActiveStorageBlob" ], output.lines.map(&:chomp).last(2)
    end

    test "attaches downloads and purges without active record" do
      require_in_memory_backend
      add_to_config <<~RUBY
        config.active_storage.service = :local
        config.active_storage.service_configurations = {
          local: { service: "Disk", root: Rails.root.join("tmp/storage") }
        }
        config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
        config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
        config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"

        initializer "active_storage.in_memory_backend", after: "active_storage.class_indirection" do |app|
          ActiveStorage::Services.setup_from_app_config(app)
          ActiveStorage::InMemoryBackend.install
        end
      RUBY

      output = rails_runner <<~RUBY
        owner_class = ActiveStorage::ActiveModelOwnerFixture.define!
        owner = owner_class.new(name: "Dorian")
        owner.avatar.attach(io: StringIO.new("hello"), filename: "hello.txt", content_type: "text/plain")
        owner.save!
        puts defined?(::ActiveRecord::Base).inspect
        raise "Active Record is in the bundle" if Bundler.load.specs.any? { |spec| spec.name == "activerecord" }
        raise "Active Record is on the load path" if $LOAD_PATH.any? { |path| path.include?("/activerecord/lib") }
        Rails.application.reload_routes!
        Rails.application.routes.default_url_options[:host] = "example.org"
        controller = ApplicationController.new
        controller.set_request!(ActionDispatch::Request.new(Rack::MockRequest.env_for("http://example.org")))
        view = controller.view_context
        puts view.url_for(owner.avatar.blob)
        puts view.url_for(owner.avatar.attachment)
        puts view.image_tag(owner.avatar)
        puts owner.avatar.download
        ActiveJob::Base.queue_adapter = :inline
        owner.avatar.purge_later
        puts owner.avatar.attached?
      RUBY

      assert_includes output, "nil\n"
      assert_equal 3, output.scan(%r{/rails/active_storage/blobs/redirect/}).size
      assert_match(/hello\n.*false\n/m, output)
    end

    test "mirrors direct uploads without active record" do
      require_in_memory_backend
      add_to_config <<~RUBY
        config.active_storage.service = :mirror
        config.active_storage.service_configurations = {
          mirror: { service: "Mirror", primary: "primary", mirrors: ["secondary"] },
          primary: { service: "Disk", root: Rails.root.join("tmp/primary") },
          secondary: { service: "Disk", root: Rails.root.join("tmp/secondary") }
        }
        config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
        config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
        config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"

        initializer "active_storage.in_memory_backend", after: :setup_main_autoloader do |app|
          ActiveStorage::Services.setup_from_app_config(app)
          ActiveStorage::InMemoryBackend.install
        end
      RUBY

      output = rails_runner <<~RUBY
        data = "mirrored without Active Record"
        blob = ActiveStorage.blob_class.create_before_direct_upload!(
          filename: "message.txt", byte_size: data.bytesize,
          checksum: ActiveStorage.checksum_implementation.base64digest(data), content_type: "text/plain"
        )
        service = blob.service
        service.primary.upload(blob.key, StringIO.new(data), checksum: blob.checksum)
        raise "file was already mirrored" if service.mirrors.first.exist?(blob.key)

        ActiveJob::Base.queue_adapter = :inline
        blob.mirror_later
        raise "Active Record was loaded" if defined?(::ActiveRecord)
        raise "Active Record is in the bundle" if Bundler.load.specs.any? { |spec| spec.name == "activerecord" }
        raise "Active Record is on the load path" if $LOAD_PATH.any? { |path| path.include?("/activerecord/lib") }
        puts service.mirrors.first.download(blob.key)
      RUBY

      assert_equal "mirrored without Active Record", output.lines.last.chomp
    end

    [false, true].each do |eager_load|
      test "loads inline backend attachments without active record with eager_load #{eager_load}" do
        application = File.read(app_path("config/application.rb"))
        application.sub!('require "active_storage/engine"', <<~RUBY)
          require "active_storage/engine"
          require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_storage/in_memory_backend").inspect}
          ActiveStorage::InMemoryBackend.install
        RUBY
        app_file "config/application.rb", application
        add_to_config <<~RUBY
          config.eager_load = #{eager_load}
          config.active_storage.service = :local
          config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
          config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
          config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"
          initializer "inline_backend.services", after: "active_storage.class_indirection" do |app|
            ActiveStorage::Services.setup_from_app_config(app)
          end
        RUBY

        output = rails_runner <<~RUBY
          raise "Active Record was loaded" if defined?(::ActiveRecord)
          blob = ActiveStorage.blob_class.create_and_upload!(io: StringIO.new("original"), filename: "original.txt")
          blob.preview_image.attach(io: StringIO.new("preview"), filename: "preview.txt")
          puts blob.preview_image.download
        RUBY

        assert_equal "preview", output.lines.last.chomp
      end
    end

    test "propagates nested active record loading errors" do
      ["active_record", "active_record/railtie"].each do |feature|
        app_file "loading_errors/#{feature}.rb", 'require "missing_active_storage_backend_dependency"'
        app_file "config/boot.rb", <<~RUBY
          require "bundler/setup"
          $LOAD_PATH.unshift #{app_path("loading_errors").inspect}
        RUBY

        output = rails_runner("puts 'booted'", allow_failure: true)

        assert_includes output, "missing_active_storage_backend_dependency"
        assert_not_includes output, "default class names"
        FileUtils.rm_f app_path("loading_errors/#{feature}.rb")
      end
    end

    private
      def use_active_storage_without_active_record
        FileUtils.rm_rf "#{app_path}/app/channels"
        FileUtils.rm_rf "#{app_path}/app/mailers"
        FileUtils.rm_f "#{app_path}/app/models/application_record.rb"
        app_file "app/controllers/application_controller.rb", "class ApplicationController < ActionController::Base; end"

        app_file "Gemfile", <<~RUBY
          source "https://rubygems.org"
          #{%w[activesupport activemodel activejob actionview actionpack activestorage railties].map { |component| %(gem #{component.inspect}, path: #{File.join(RAILS_FRAMEWORK_ROOT, component).inspect}) }.join("\n")}
        RUBY
        app_file "config/boot.rb", 'require "bundler/setup"'

        application = File.read("#{app_path}/config/application.rb")
        application.sub!(/^%w\(propshaft importmap-rails\).*$/, "")
        application.gsub! <<~RUBY.strip, <<~RUBY.strip
          require "rails/all"
        RUBY
          require "rails"
          require "action_controller/railtie"
          require "active_job/railtie"
          require "active_storage/engine"
        RUBY
        File.write("#{app_path}/config/application.rb", application)
        add_to_config <<~RUBY
          config.cache_store = :memory_store
          config.active_storage.variant_processor = :disabled
        RUBY

        output, status = isolated_command(Gem.ruby, Gem.bin_path("bundler", "bundle"), "lock", "--local")
        assert_predicate status, :success?, output
      end

      def require_in_memory_backend
        root = Pathname.new(__dir__).join("../../..").expand_path
        add_to_top_of_config <<~RUBY
          require #{root.join("activestorage/test/fixtures/active_storage/in_memory_backend").to_s.inspect}
          require #{root.join("activestorage/test/fixtures/active_model_owner").to_s.inspect}
        RUBY
      end

      def rails_runner(script, allow_failure: false)
        output, status = isolated_command(Gem.ruby, "bin/rails", "runner", script)
        assert_predicate status, :success?, output unless allow_failure
        output
      end

      def isolated_command(*command)
        Bundler.with_original_env do
          Open3.capture2e({ "BUNDLE_GEMFILE" => app_path("Gemfile"), "RUBYLIB" => nil, "RUBYOPT" => nil }, *command, chdir: app_path)
        end
      end

      def define_custom_storage_classes
        application = File.read("#{app_path}/config/application.rb")
        application.sub!(/^(module .*)$/, <<~RUBY.chomp + "\n\\1")
          class CustomActiveStorageBlob; end
          class CustomActiveStorageAttachment; end
          class CustomActiveStorageVariantRecord; end
        RUBY
        File.write("#{app_path}/config/application.rb", application)
      end
  end
end

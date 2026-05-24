# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_storage"

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

    private
      def use_active_storage_without_active_record
        FileUtils.rm_rf "#{app_path}/app/channels"
        FileUtils.rm_rf "#{app_path}/app/mailers"
        FileUtils.rm_f "#{app_path}/app/models/application_record.rb"

        boot = File.read("#{app_path}/config/boot.rb")
        boot.gsub!("\nrequire \"rails/all\"", "")
        File.write("#{app_path}/config/boot.rb", boot)

        application = File.read("#{app_path}/config/application.rb")
        application.gsub! <<~RUBY.strip, <<~RUBY.strip
          require "rails/all"
        RUBY
          require "rails"
          require "action_controller/railtie"
          require "active_job/railtie"
          require "active_storage/engine"
        RUBY
        File.write("#{app_path}/config/application.rb", application)
      end

      def rails_runner(script, allow_failure: false)
        with_env("NO_FORK" => "1") do
          rails [ "runner", script ], allow_failure: allow_failure
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

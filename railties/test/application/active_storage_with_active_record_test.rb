# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_storage"

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
        puts ActiveStorage::Attached::Builder::ActiveRecordOwner.declared_classes.map(&:name).inspect
      RUBY

      assert_equal [ "ar_loaded", "CustomActiveStorageBlob", "[]" ], output.lines.map(&:chomp).last(3)
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

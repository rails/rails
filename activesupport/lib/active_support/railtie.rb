# frozen_string_literal: true

require "active_support"
require "active_support/i18n_railtie"

module ActiveSupport
  class Railtie < Rails::Railtie # :nodoc:
    config.active_support = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveSupport

    initializer "active_support.deprecator", before: :load_environment_config do |app|
      app.deprecators[:active_support] = ActiveSupport.deprecator
    end

    initializer "active_support.isolation_level" do |app|
      config.after_initialize do
        if level = app.config.active_support.isolation_level
          ActiveSupport::IsolatedExecutionState.isolation_level = level
        end
      end
    end

    initializer "active_support.raise_on_invalid_cache_expiration_time" do |app|
      config.after_initialize do
        if app.config.active_support.raise_on_invalid_cache_expiration_time
          ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time = true
        end
      end
    end

    initializer "active_support.set_authenticated_message_encryption" do |app|
      config.after_initialize do
        unless app.config.active_support.use_authenticated_message_encryption.nil?
          ActiveSupport::MessageEncryptor.use_authenticated_message_encryption =
            app.config.active_support.use_authenticated_message_encryption
        end
      end
    end

    initializer "active_support.set_event_reporter_context_store" do |app|
      config.after_initialize do
        if klass = app.config.active_support.event_reporter_context_store
          ActiveSupport::EventReporter.context_store = klass
        end
      end
    end

    initializer "active_support.reset_execution_context" do |app|
      app.reloader.before_class_unload do
        ActiveSupport::CurrentAttributes.clear_all
        ActiveSupport::ExecutionContext.clear
        ActiveSupport.event_reporter.clear_context
      end

      app.executor.to_run do
        ActiveSupport::ExecutionContext.push
      end

      app.executor.to_complete do
        ActiveSupport::CurrentAttributes.clear_all
        ActiveSupport::ExecutionContext.pop
        ActiveSupport.event_reporter.clear_context
      end

      ActiveSupport.on_load(:active_support_test_case) do
        if app.config.active_support.executor_around_test_case
          ActiveSupport::ExecutionContext.nestable = true

          require "active_support/executor/test_helper"
          include ActiveSupport::Executor::TestHelper
        else
          require "active_support/current_attributes/test_helper"
          include ActiveSupport::CurrentAttributes::TestHelper

          require "active_support/execution_context/test_helper"
          include ActiveSupport::ExecutionContext::TestHelper
        end
      end
    end

    initializer "active_support.set_filter_parameters" do |app|
      config.after_initialize do
        ActiveSupport.filter_parameters += Rails.application.config.filter_parameters
        ActiveSupport.event_reporter.reload_payload_filter
      end
    end

    initializer "active_support.deprecation_behavior" do |app|
      if app.config.active_support.report_deprecations == false
        app.deprecators.silenced = true
        app.deprecators.behavior = :silence
        app.deprecators.disallowed_behavior = :silence
      else
        if deprecation = app.config.active_support.deprecation
          app.deprecators.behavior = deprecation
        end

        if disallowed_deprecation = app.config.active_support.disallowed_deprecation
          app.deprecators.disallowed_behavior = disallowed_deprecation
        end

        if disallowed_warnings = app.config.active_support.disallowed_deprecation_warnings
          app.deprecators.disallowed_warnings = disallowed_warnings
        end
      end
    end

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer "active_support.initialize_time_zone" do |app|
      begin
        TZInfo::DataSource.get
      rescue TZInfo::DataSourceNotFound => e
        raise e.exception('tzinfo-data is not present. Please add gem "tzinfo-data" to your Gemfile and run bundle install')
      end
      require "active_support/core_ext/time/zones"
      Time.zone_default = Time.find_zone!(app.config.time_zone)
      config.eager_load_namespaces << TZInfo
    end

    # Sets the default week start
    # If assigned value is not a valid day symbol (e.g. :sunday, :monday, ...), an exception will be raised.
    initializer "active_support.initialize_beginning_of_week" do |app|
      require "active_support/core_ext/date/calculations"
      beginning_of_week_default = Date.find_beginning_of_week!(app.config.beginning_of_week)

      Date.beginning_of_week_default = beginning_of_week_default
    end

    initializer "active_support.require_master_key" do |app|
      if app.config.respond_to?(:require_master_key) && app.config.require_master_key
        begin
          app.credentials.key
        rescue ActiveSupport::EncryptedFile::MissingKeyError => error
          $stderr.puts error.message
          exit 1
        end
      end
    end

    initializer "active_support.set_configs" do |app|
      app.config.active_support.each do |k, v|
        k = "#{k}="
        ActiveSupport.public_send(k, v) if ActiveSupport.respond_to? k
      end
    end

    initializer "active_support.set_hash_digest_class" do |app|
      config.after_initialize do
        if klass = app.config.active_support.hash_digest_class
          ActiveSupport::Digest.hash_digest_class = klass
        end
      end
    end

    initializer "active_support.set_key_generator_hash_digest_class" do |app|
      config.after_initialize do
        if klass = app.config.active_support.key_generator_hash_digest_class
          ActiveSupport::KeyGenerator.hash_digest_class = klass
        end
      end
    end

    initializer "active_support.set_default_message_serializer" do |app|
      config.after_initialize do
        if message_serializer = app.config.active_support.message_serializer
          ActiveSupport::Messages::Codec.default_serializer = message_serializer
        end
      end
    end

    initializer "active_support.set_use_message_serializer_for_metadata" do |app|
      config.after_initialize do
        ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata =
          app.config.active_support.use_message_serializer_for_metadata
      end
    end
  end
end

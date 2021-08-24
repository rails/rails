# frozen_string_literal: true

require "global_id/railtie"
require "active_job"

module ActiveJob
  # = Active Job Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.active_job = ActiveSupport::OrderedOptions.new
    config.active_job.custom_serializers = []
    config.active_job.log_query_tags_around_perform = true

    initializer "active_job.logger" do
      ActiveSupport.on_load(:active_job) { self.logger = ::Rails.logger }
    end

    initializer "active_job.custom_serializers" do |app|
      config.after_initialize do
        custom_serializers = app.config.active_job.custom_serializers
        ActiveJob::Serializers.add_serializers custom_serializers
      end
    end

    initializer "active_job.set_configs" do |app|
      options = app.config.active_job
      options.queue_adapter ||= :async

      ActiveSupport.on_load(:active_job) do
        # Configs used in other initializers
        options = options.except(
          :log_query_tags_around_perform,
          :custom_serializers
        )

        options.each do  |k, v|
          k = "#{k}="
          send(k, v) if respond_to? k
        end
      end

      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include ActiveJob::TestHelper
      end

      ActiveSupport.on_load(:active_record) do
        self.destroy_association_async_job = ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    initializer "active_job.set_reloader_hook" do |app|
      ActiveSupport.on_load(:active_job) do
        ActiveJob::Callbacks.singleton_class.set_callback(:execute, :around, prepend: true) do |_, inner|
          app.reloader.wrap do
            inner.call
          end
        end
      end
    end

    initializer "active_job.query_log_tags" do |app|
      query_logs_tags_enabled = app.config.respond_to?(:active_record) &&
        app.config.active_record.query_log_tags_enabled &&
        app.config.active_job.log_query_tags_around_perform

      if query_logs_tags_enabled
        app.config.active_record.query_log_tags << :job

        ActiveSupport.on_load(:active_job) do
          include ActiveJob::QueryTags
        end

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::QueryLogs.taggings[:job] = ->(context) { context[:job].class.name unless context[:job].nil? }
        end
      end
    end
  end
end

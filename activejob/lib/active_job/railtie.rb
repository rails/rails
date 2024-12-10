# frozen_string_literal: true

require "global_id/railtie"
require "active_job"

module ActiveJob
  # = Active Job Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.active_job = ActiveSupport::OrderedOptions.new
    config.active_job.custom_serializers = []
    config.active_job.log_query_tags_around_perform = true

    initializer "active_job.deprecator", before: :load_environment_config do |app|
      app.deprecators[:active_job] = ActiveJob.deprecator
    end

    initializer "active_job.logger" do
      ActiveSupport.on_load(:active_job) { self.logger = ::Rails.logger }
    end

    initializer "active_job.custom_serializers" do |app|
      config.after_initialize do
        custom_serializers = app.config.active_job.custom_serializers
        ActiveJob::Serializers.add_serializers custom_serializers
      end
    end

    initializer "active_job.enqueue_after_transaction_commit" do |app|
      ActiveSupport.on_load(:active_job) do
        ActiveSupport.on_load(:active_record) do
          ActiveJob::Base.include EnqueueAfterTransactionCommit

          if app.config.active_job.key?(:enqueue_after_transaction_commit)
            ActiveJob.deprecator.warn(<<~MSG.squish)
              `config.active_job.enqueue_after_transaction_commit` is deprecated and will be removed in Rails 8.1.
              This configuration can still be set on individual jobs using `self.enqueue_after_transaction_commit=`,
              but due the nature of this behavior, it is not recommended to be set globally.
            MSG

            value = case app.config.active_job.enqueue_after_transaction_commit
            when :always
              true
            when :never
              false
            else
              false
            end

            ActiveJob::Base.enqueue_after_transaction_commit = value
          end
        end
      end
    end

    initializer "active_job.set_configs" do |app|
      options = app.config.active_job
      options.queue_adapter ||= (Rails.env.test? ? :test : :async)

      config.after_initialize do
        options.each do |k, v|
          k = "#{k}="
          if ActiveJob.respond_to?(k)
            ActiveJob.send(k, v)
          end
        end
      end

      ActiveSupport.on_load(:active_job) do
        # Configs used in other initializers
        options = options.except(
          :log_query_tags_around_perform,
          :custom_serializers,
          :enqueue_after_transaction_commit
        )

        options.each do |k, v|
          k = "#{k}="
          if ActiveJob.respond_to?(k)
            ActiveJob.send(k, v)
          elsif respond_to? k
            send(k, v)
          end
        end
      end

      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include ActiveJob::TestHelper
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
        app.config.active_record.query_log_tags |= [:job]

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::QueryLogs.taggings = ActiveRecord::QueryLogs.taggings.merge(
            job: ->(context) { context[:job].class.name if context[:job] }
          )
        end
      end
    end

    initializer "active_job.backtrace_cleaner" do
      ActiveSupport.on_load(:active_job) do
        LogSubscriber.backtrace_cleaner = ::Rails.backtrace_cleaner
      end
    end
  end
end

# frozen_string_literal: true

# :markup: markdown

module ActiveJob # :nodoc:
  # Raised when a job exceeds its rate limit
  class RateLimitExceeded < StandardError; end

  # The cache store to use for rate limiting. Defaults to Rails.cache.
  mattr_accessor :rate_limit_cache_store

  # Provides rate limiting functionality for Active Job
  #
  # Similar to ActionController's rate limiting, this uses a backing cache store
  # to track execution counts and enforce limits.
  #
  # ==== Examples
  #
  #   class NewsletterJob < ApplicationJob
  #     rate_limit to: 100, within: 1.hour
  #
  #     def perform(user)
  #       NewsletterMailer.weekly(user).deliver_now
  #     end
  #   end
  #
  #   class DataImportJob < ApplicationJob
  #     rate_limit to: 10, within: 5.minutes, by: -> { arguments.first }
  #
  #     def perform(account_id, import_data)
  #       # Import processing
  #     end
  #   end
  #
  module RateLimiting
    extend ActiveSupport::Concern

    module ClassMethods
      # Applies a rate limit to job execution.
      #
      # The maximum number of executions allowed is specified by +to:+ and constrained
      # to the window of time given by +within:+.
      #
      # Rate limits are by default scoped to the job class, but you can provide your own
      # identity function by passing a callable in the +by:+ parameter. It's evaluated
      # within the context of the job instance.
      #
      # Jobs that exceed the rate limit will raise a RateLimitExceeded error by default.
      # You can customize this behavior by passing a callable in the +with:+ parameter.
      # Common patterns include retrying the job later or logging and discarding.
      #
      # Rate limiting relies on a backing ActiveSupport::Cache store. It defaults to
      # Rails.cache. You can pass a custom store in the +store:+ parameter or configure it globally with
      # +ActiveJob.rate_limit_cache_store = ...+
      #
      # If you want to use multiple rate limits per job, you need to give each of them
      # an explicit name via the +name:+ option.
      #
      # Examples:
      #
      #     class ProcessOrderJob < ApplicationJob
      #       rate_limit to: 100, within: 1.minute
      #     end
      #
      #     class SendEmailJob < ApplicationJob
      #       rate_limit to: 5, within: 1.hour, by: -> { arguments.first[:user_id] }
      #     end
      #
      #     class DataSyncJob < ApplicationJob
      #       rate_limit to: 10, within: 5.minutes, with: -> { retry_job(wait: 30.seconds) }
      #     end
      #
      #     class ApiCallJob < ApplicationJob
      #       rate_limit to: 10, within: 1.second, name: "burst"
      #       rate_limit to: 1000, within: 1.hour, name: "sustained"
      #     end
      def rate_limit(to:, within:, by: nil, with: -> { raise RateLimitExceeded, "Rate limit exceeded for #{self.class.name}" }, store: nil, name: nil)
        store ||= ActiveJob.rate_limit_cache_store
        before_perform -> { rate_limiting(to: to, within: within, by: by, with: with, store: store, name: name) }
      end
    end

    private
      def rate_limiting(to:, within:, by:, with:, store:, name:)
        cache_key = ["aj-rate-limit", self.class.name, name, by ? instance_exec(&by) : nil].compact.join(":")
        count = store.increment(cache_key, 1, expires_in: within)

        if count && count > to
          ActiveSupport::Notifications.instrument("rate_limit.active_job", job: self) do
            instance_exec(&with)
          end
        end
      end
  end
end

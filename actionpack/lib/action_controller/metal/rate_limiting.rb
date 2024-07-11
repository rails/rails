# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module RateLimiting
    extend ActiveSupport::Concern

    module ClassMethods
      # Applies a rate limit to all actions or those specified by the normal
      # `before_action` filters with `only:` and `except:`.
      #
      # The maximum number of requests allowed is specified `to:` and constrained to
      # the window of time given by `within:`.
      #
      # Rate limits are by default unique to the ip address making the request, but
      # you can provide your own identity function by passing a callable in the `by:`
      # parameter. It's evaluated within the context of the controller processing the
      # request.
      #
      # Requests that exceed the rate limit are refused with a `429 Too Many Requests`
      # response. You can specialize this by passing a callable in the `with:`
      # parameter. It's evaluated within the context of the controller processing the
      # request.
      #
      # Rate limiting relies on a backing `ActiveSupport::Cache` store and defaults to
      # `config.action_controller.cache_store`, which itself defaults to the global
      # `config.cache_store`. If you don't want to store rate limits in the same
      # datastore as your general caches, you can pass a custom store in the `store`
      # parameter.
      #
      # RateLimiting implements fixed window algorithm by default, but you can switch
      # to sliding window by passing `strategy: :sliding_window`. You can also pass a
      # custom strategy class in the `strategy` parameter, as long as it implements
      # the BaseStrategy interface.
      #
      # Examples:
      #
      #     class SessionsController < ApplicationController
      #       rate_limit to: 10, within: 3.minutes, only: :create
      #     end
      #
      #     class SignupsController < ApplicationController
      #       rate_limit to: 1000, within: 10.seconds,
      #         by: -> { request.domain }, with: -> { redirect_to busy_controller_url, alert: "Too many signups on domain!" }, only: :new
      #     end
      #
      #     class APIController < ApplicationController
      #       RATE_LIMIT_STORE = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
      #       rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE
      #     end
      #
      #     class SessionsController < ApplicationController
      #       rate_limit to: 10, within: 3.minutes, only: :create, strategy :sliding_window
      #     end
      def rate_limit(to:, within:, by: -> { request.remote_ip }, with: -> { head :too_many_requests }, store: cache_store, strategy: :fixed_window, **options)
        before_action -> { rate_limiting(to: to, within: within, by: by, with: with, store: store, strategy: strategy) }, **options
      end
    end

    class BaseStrategy
      attr_reader :to, :within, :store

      def initialize(to:, within:, store:)
        @to = to
        @within = within
        @store = store
      end

      def increment_and_check(key:)
        raise NotImplementedError, "Subclasses must implement `increment_and_check` method"
      end
    end

    private
      def rate_limiting(to:, within:, by:, with:, store:, strategy:)
        key = "rate-limit:#{controller_path}:#{instance_exec(&by)}"
        strategy_class = if strategy.is_a?(Class)
          strategy
        elsif STRATEGY_CLASSES.key?(strategy)
          STRATEGY_CLASSES[strategy]
        else
          raise ArgumentError, "Unknown rate limiting strategy: #{strategy}"
        end

        limiter = strategy_class.new(to: to, within: within, store: store)

        if limiter.increment_and_check(key: key)
          ActiveSupport::Notifications.instrument("rate_limit.action_controller", request: request) do
            instance_exec(&with)
          end
        end
      end

      class FixedWindowStrategy < BaseStrategy
        def increment_and_check(key:)
          count = store.increment(key, 1, expires_in: within)
          count && count > to
        end
      end

      class SlidingWindowStrategy < BaseStrategy
        def increment_and_check(key:)
          current_time = Time.now.to_f
          bucket = (store.read(key) || []).select { |timestamp| timestamp > current_time - within }
          bucket.push(current_time)
          store.write(key, bucket, expires_in: within)
          if bucket.size > to
            true
          else
            false
          end
        end
      end

      STRATEGY_CLASSES = {
        fixed_window: FixedWindowStrategy,
        sliding_window: SlidingWindowStrategy
      }.freeze
  end
end

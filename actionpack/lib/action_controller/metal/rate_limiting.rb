# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module RateLimiting
    extend ActiveSupport::Concern

    RateLimit = Struct.new(:name, :count, :retry_after) # :nodoc:

    module Request # :nodoc:
      RATE_LIMIT = "action_controller.metal.rate_limiting" # :nodoc:

      def rate_limit
        get_header RATE_LIMIT
      end

      def rate_limit=(value)
        set_header RATE_LIMIT, value
      end
    end

    module Response # :nodoc:
      RETRY_AFTER = "retry-after"

      def retry_after=(value)
        set_header RETRY_AFTER, value&.httpdate
      end

      def retry_after
        get_header RETRY_AFTER
      end
    end

    module ClassMethods
      # Applies a rate limit to all actions or those specified by the normal
      # `before_action` filters with `only:` and `except:`.
      #
      # The maximum number of requests allowed is specified `to:` and constrained to
      # the window of time given by `within:`.
      #
      # Rate limits are unique to the IP address making the request, by default.
      # You can provide your own identity function by passing a method name or a callable in the `by:`
      # parameter. Callables are evaluated within the context of the controller processing the
      # request.
      #
      # Requests that exceed the rate limit will raise an `ActionController::TooManyRequests`
      # error. By default, Action Dispatch will rescue from the error and refuse the request
      # with a `429 Too Many Requests` response.
      #
      # You can specialize this by passing either a method name or a callable in the `with:`
      # parameter. Callables are evaluated within the context of the controller processing the
      # request.
      #
      # Rate limiting relies on a backing `ActiveSupport::Cache` store and defaults to
      # `config.action_controller.cache_store`, which itself defaults to the global
      # `config.cache_store`. If you don't want to store rate limits in the same
      # datastore as your general caches, you can pass a custom store in the `store`
      # parameter.
      #
      # If you want to use multiple rate limits per controller, you need to give each of
      # them an explicit name via the `name:` option.
      #
      # Examples:
      #
      #     class SessionsController < ApplicationController
      #       rate_limit to: 10, within: 3.minutes, only: :create
      #     end
      #
      #     class SignupsController < ApplicationController
      #       rate_limit to: 1000, within: 10.seconds,
      #         by: -> { request.domain }, with: :redirect_to_busy, only: :new
      #
      #       private
      #         def redirect_to_busy
      #           redirect_to busy_controller_url, alert: "Too many signups on domain!"
      #         end
      #     end
      #
      #     class APIController < ApplicationController
      #       RATE_LIMIT_STORE = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
      #       rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE
      #     end
      #
      #     class SessionsController < ApplicationController
      #       rate_limit to: 3.times, within: 2.seconds, name: "short-term"
      #       rate_limit to: 10.times, within: 5.minutes, name: "long-term"
      #     end
      def rate_limit(to:, within:, by: :rate_limit_by, with: :rate_limit_with, store: cache_store, name: nil, **options)
        to = to.size if to.is_a?(Enumerator)

        before_action -> { rate_limiting(to: to, within: within, by: by, with: with, store: store, name: name) }, **options
      end
    end

    private
      def rate_limiting(to:, within:, by:, with:, store:, name:)
        callable = ->(c) { c.is_a?(Symbol) ? send(c) : instance_exec(&c) }

        cache_key = ["rate-limit", controller_path, name, callable.call(by)].compact.join(":")
        count = store.increment(cache_key, 1, expires_in: within)
        if count && count > to
          request.rate_limit = RateLimit.new(name: name, count: to, retry_after: within.from_now)

          ActiveSupport::Notifications.instrument("rate_limit.action_controller", request: request) do
            callable.call(with)
          end
        end
      end

      def rate_limit_by
        request.remote_ip
      end

      def rate_limit_with
        response.retry_after = request.rate_limit.retry_after

        raise TooManyRequests.new
      end
  end
end

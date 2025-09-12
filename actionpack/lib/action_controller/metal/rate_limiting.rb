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
      # By default, rate limits are scoped to the controller's path. If you want to
      # share rate limits across multiple controllers, you can provide your own scope,
      # by passing value in the `scope:` parameter.
      #
      # Requests that exceed the rate limit will raise an `ActionController::TooManyRequests`
      # error. By default, Action Dispatch will rescue from the error and refuse the request
      # with a `429 Too Many Requests` response. You can specialize this by passing a callable in the `with:`
      # parameter. It's evaluated within the context of the controller processing the
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
      #       rate_limit to: 100, within: 5.minutes, scope: :api_global
      #     end
      #
      #     class SessionsController < ApplicationController
      #       rate_limit to: 3, within: 2.seconds, name: "short-term"
      #       rate_limit to: 10, within: 5.minutes, name: "long-term"
      #     end
      def rate_limit(to:, within:, by: -> { request.remote_ip }, with: -> { raise TooManyRequests }, store: cache_store, name: nil, scope: nil, **options)
        before_action -> { rate_limiting(to: to, within: within, by: by, with: with, store: store, name: name, scope: scope || controller_path) }, **options
      end
    end

    private
      def rate_limiting(to:, within:, by:, with:, store:, name:, scope:)
        by = by.is_a?(Symbol) ? send(by) : instance_exec(&by)

        cache_key = ["rate-limit", scope, name, by].compact.join(":")
        count = store.increment(cache_key, 1, expires_in: within)
        if count && count > to
          ActiveSupport::Notifications.instrument("rate_limit.action_controller",
              request: request,
              count: count,
              to: to,
              within: within,
              by: by,
              name: name,
              scope: scope,
              cache_key: cache_key) do
            with.is_a?(Symbol) ? send(with) : instance_exec(&with)
          end
        end
      end
  end
end

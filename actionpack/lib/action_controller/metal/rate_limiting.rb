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
      def rate_limit(to:, within:, by: -> { request.remote_ip }, with: -> { head :too_many_requests }, store: cache_store, **options)
        before_action -> { rate_limiting(to: to, within: within, by: by, with: with, store: store) }, **options
      end
    end

    private
      def rate_limiting(to:, within:, by:, with:, store:)
        count = store.increment("rate-limit:#{controller_path}:#{instance_exec(&by)}", 1, expires_in: within)
        if count && count > to
          ActiveSupport::Notifications.instrument("rate_limit.action_controller", request: request) do
            instance_exec(&with)
          end
        end
      end
  end
end

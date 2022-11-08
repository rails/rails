# frozen_string_literal: true

module AbstractController # :nodoc:
  module Ratelimiter
    extend ActiveSupport::Concern

    module ClassMethods
      # Registers a <tt>before_action</tt> callback wrapped by a rate limit logic.
      #
      # To use +ratelimit+, you should have kredis installed in your application,
      # therefore follow these steps:
      #
      # ==== Kredis installation
      # * Run ./bin/bundle add kredis
      # * Run ./bin/rails kredis:install to add a default configuration at config/redis/shared.yml
      #
      # ==== Options
      # * <tt>with</tt> - The method that will be called if the rate limit is exceeded,
      #   the request cycle can be halt by a <tt>render</tt> or <tt>redirect_to</tt>.
      #   Alternatively, a block can be given as the handler.
      # * <tt>limit</tt> - The maximum number of permitted requests (default: 10).
      # * <tt>period</tt> - The amount of time where requests are permitted (default: 1.hour).
      # * <tt>only</tt> - The rate limit should be run only for this action.
      # * <tt>except</tt> - The rate limit should be run for all actions except this action.
      #
      # ==== Examples
      #   class PasswordResetsController < ActionController::Base
      #     ratelimit with: :deny_access
      #     ratelimit with: :deny_access, only: :create
      #     ratelimit with: :redirect_to_root, limit: 30, period: 5.minutes
      #
      #     ratelimit limit: 15, period: 3.minutes do
      #       render json: { error: "You've exceeded the maximum number of attempts" }, status: :too_many_requests
      #     end
      #
      #     private
      #       def deny_access
      #         head :too_many_requests
      #       end
      #
      #       def redirect_to_root
      #         redirect_to root_url, alert: "You've exceeded the maximum number of attempts"
      #       end
      #   end
      def ratelimit(options = {}, with: nil, limit: 10, period: 1.hour, &block)
        begin
          require "kredis"
        rescue LoadError
          $stderr.puts "You don't have kredis installed in your application. Please add it to your Gemfile and run bundle install."
          raise
        end

        before_action(options) do
          counter = Kredis.counter(ratelimit_key, expires_in: period)
          counter.increment

          if counter.value > limit
            block_given? ? instance_exec(&block) : send(with)
          end
        end
      end
    end

    private
      def ratelimit_key
        "ratelimiter:#{request.remote_ip}:#{controller_name}:#{action_name}"
      end
  end
end

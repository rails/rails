# frozen_string_literal: true

module ActiveRecord
  module Middleware
    # The ShardSelector Middleware provides a framework for automatically
    # swapping shards. Rails provides a basic framework to determine which
    # shard to switch to and allows for applications to write custom strategies
    # for swapping if needed.
    #
    # The ShardSelector takes a set of options (currently only +lock+ is supported)
    # that can be used by the middleware to alter behavior. +lock+ is
    # true by default and will prohibit the request from switching shards once
    # inside the block. If +lock+ is false, then shard swapping will be allowed.
    # For tenant based sharding, +lock+ should always be true to prevent application
    # code from mistakenly switching between tenants.
    #
    # To use the ShardSelector in your application with default settings,
    # run the provided generator.
    #
    #   bin/rails g active_record:multi_db
    #
    # This will create a file named +config/initializers/multi_db.rb+. Find the following
    # code and uncomment it.
    #
    #   Rails.application.configure do
    #     options = { lock: true }
    #     resolver = ->(request) { Tenant.find_by!(host: request.host).shard }
    #
    #     config.middleware.use ActiveRecord::Middleware::ShardSelector, resolver, options
    #   end
    #
    # Applications must also provide the code for the resolver as it depends on application
    # specific models. An example resolver would look like this:
    #
    #   Rails.application.configure do
    #     resolver = ->(request) {
    #       subdomain = request.subdomain
    #       tenant = Tenant.find_by_subdomain!(subdomain)
    #       tenant.shard
    #     }
    #
    #     config.middleware.use ActiveRecord::Middleware::ShardSelector, resolver
    #   end
    class ShardSelector
      def initialize(app, resolver, options = {})
        @app = app
        @resolver = resolver
        @options = options
      end

      attr_reader :resolver, :options

      def call(env)
        request = ActionDispatch::Request.new(env)

        shard = selected_shard(request)

        set_shard(shard) do
          @app.call(env)
        end
      end

      private
        def selected_shard(request)
          resolver.call(request)
        end

        def set_shard(shard, &block)
          ActiveRecord::Base.connected_to(shard: shard.to_sym) do
            ActiveRecord::Base.prohibit_shard_swapping(options.fetch(:lock, true), &block)
          end
        end
    end
  end
end

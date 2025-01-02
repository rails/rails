# frozen_string_literal: true

module ActiveRecord
  module Middleware
    # = Shard Selector \Middleware
    #
    # The ShardSelector Middleware provides a framework for automatically
    # swapping shards. \Rails provides a basic framework to determine which
    # shard to switch to and allows for applications to write custom strategies
    # for swapping if needed.
    #
    # == Setup
    #
    # Applications must provide a resolver that will provide application-specific logic for
    # selecting the appropriate shard. Setting +config.active_record.shard_resolver+ will cause
    # Rails to add ShardSelector to the default middleware stack.
    #
    # The resolver, along with any configuration options, can be set in the application
    # configuration using an initializer like so:
    #
    #   Rails.application.configure do
    #     config.active_record.shard_selector = { lock: false, class_name: "AnimalsRecord" }
    #     config.active_record.shard_resolver = ->(request) {
    #       subdomain = request.subdomain
    #       tenant = Tenant.find_by_subdomain!(subdomain)
    #       tenant.shard
    #     }
    #   end
    #
    # == Configuration
    #
    # The behavior of ShardSelector can be altered through some configuration options.
    #
    # [+lock:+]
    #   +lock+ is true by default and will prohibit the request from switching shards once inside
    #   the block. If +lock+ is false, then shard switching will be allowed. For tenant based
    #   sharding, +lock+ should always be true to prevent application code from mistakenly switching
    #   between tenants.
    #
    # [+class_name:+]
    #   +class_name+ is the name of the abstract connection class to switch. By
    #   default, the ShardSelector will use ActiveRecord::Base, but if the
    #   application has multiple databases, then this option should be set to
    #   the name of the sharded database's abstract connection class.
    #
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
          klass = options[:class_name]&.constantize || ActiveRecord::Base

          klass.connected_to(shard: shard.to_sym) do
            klass.prohibit_shard_swapping(options.fetch(:lock, true), &block)
          end
        end
    end
  end
end

# frozen_string_literal: true

require 'active_record/middleware/database_selector/resolver'

module ActiveRecord
  module Middleware
    # The DatabaseSelector Middleware provides a framework for automatically
    # swapping from the primary to the replica database connection. Rails
    # provides a basic framework to determine when to swap and allows for
    # applications to write custom strategy classes to override the default
    # behavior.
    #
    # The resolver class defines when the application should switch (i.e. read
    # from the primary if a write occurred less than 2 seconds ago) and a
    # resolver context class that sets a value that helps the resolver class
    # decide when to switch.
    #
    # Rails default middleware uses the request's session to set a timestamp
    # that informs the application when to read from a primary or read from a
    # replica.
    #
    # To use the DatabaseSelector in your application with default settings add
    # the following options to your environment config:
    #
    #   config.active_record.database_selector = { delay: 2.seconds }
    #   config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
    #   config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
    #
    # New applications will include these lines commented out in the production.rb.
    #
    # The default behavior can be changed by setting the config options to a
    # custom class:
    #
    #   config.active_record.database_selector = { delay: 2.seconds }
    #   config.active_record.database_resolver = MyResolver
    #   config.active_record.database_resolver_context = MyResolver::MySession
    class DatabaseSelector
      def initialize(app, resolver_klass = nil, context_klass = nil, options = {})
        @app = app
        @resolver_klass = resolver_klass || Resolver
        @context_klass = context_klass || Resolver::Session
        @options = options
      end

      attr_reader :resolver_klass, :context_klass, :options

      # Middleware that determines which database connection to use in a multiple
      # database application.
      def call(env)
        request = ActionDispatch::Request.new(env)

        select_database(request) do
          @app.call(env)
        end
      end

      private
        def select_database(request, &blk)
          context = context_klass.call(request)
          resolver = resolver_klass.call(context, options)

          response = if reading_request?(request)
            resolver.read(&blk)
          else
            resolver.write(&blk)
          end

          resolver.update_context(response)
          response
        end

        def reading_request?(request)
          request.get? || request.head?
        end
    end
  end
end

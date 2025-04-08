# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module Middleware
    # # Strict Safe HTTP Methods \Middleware
    #
    # This middleware prevents database writes while serving a "safe" HTTP request (`GET`, `HEAD`, or
    # `OPTIONS`) by raising an `ActiveRecord::ReadOnlyError` exception if a database write is
    # attempted.
    #
    # Disabled by default, this middleware can be added by setting
    # `config.active_record.strict_safe_http_methods` to `true`.
    class StrictSafeHTTPMethods
      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if request.get? || request.head? || request.options?
          ActiveRecord::Base.while_preventing_writes do
            @app.call(env)
          end
        else
          @app.call(env)
        end
      end
    end
  end
end

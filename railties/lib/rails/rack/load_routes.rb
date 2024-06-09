# frozen_string_literal: true

module Rails
  module Rack
    class LoadRoutes
      def initialize(app)
        @app = app
        @called = false
      end

      def call(env)
        @called ||= begin
          Rails.application.reload_routes_unless_loaded
          true
        end
        @app.call(env)
      end
    end
  end
end

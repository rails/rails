# frozen_string_literal: true

module Rails
  module Rack
    class LoadRoutes
      def initialize(app, routes_reloader)
        @app = app
        @called = false
        @routes_reloader = routes_reloader
      end

      def call(env)
        @called ||= begin
          @routes_reloader.execute_unless_loaded
          true
        end
        @app.call(env)
      end
    end
  end
end

# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Endpoint # :nodoc:
      def dispatcher?;   false; end
      def redirect?;     false; end
      def matches?(_req);  true; end
      def app;            self; end
      def rack_app;        app; end

      def engine?
        rack_app.is_a?(Class) && rack_app < Rails::Engine
      end
    end
  end
end

# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Endpoint # :nodoc:
      def dispatcher?;                           false; end
      def redirect?;                             false; end
      def engine?;       rack_app.respond_to?(:routes); end
      def matches?(req);                          true; end
      def app;                                    self; end
      def rack_app;                                app; end
    end
  end
end

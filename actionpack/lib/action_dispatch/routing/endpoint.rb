module ActionDispatch
  module Routing
    class Endpoint # :nodoc:
      def dispatcher?;   false; end
      def redirect?;     false; end
      def matches?(req); true;  end
      def app;           self;  end
    end
  end
end

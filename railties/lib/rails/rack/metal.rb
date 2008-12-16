module Rails
  module Rack
    class Metal
      NotFound = lambda { |env|
        [404, {"Content-Type" => "text/html"}, "Not Found"]
      }

      def self.call(env)
        new(NotFound).call(env)
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end

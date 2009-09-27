module Rails
  class Application
    attr_accessor :middleware, :routes

    def initialize
      @middleware = ActionDispatch::MiddlewareStack.new
      @routes = ActionController::Routing::Routes
    end

    def call(env)
      @app ||= middleware.build(@routes)
      @app.call(env)
    end
  end
end

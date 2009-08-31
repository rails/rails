module ActionController
  class Middleware < Metal
    class ActionMiddleware
      def initialize(controller)
        @controller = controller
      end

      def call(env)
        controller = @controller.allocate
        controller.send(:initialize)
        controller.app = @app
        controller._call(env)
      end

      def app=(app)
        @app = app
      end
    end
    
    def self.new(app)
      middleware = ActionMiddleware.new(self)
      middleware.app = app
      middleware
    end
    
    def _call(env)
      @_env = env
      @_request = ActionDispatch::Request.new(env)
      @_response = ActionDispatch::Response.new
      @_response.request = @_request
      process(:index)
    end
    
    def index
      call(env)
    end
  end
end
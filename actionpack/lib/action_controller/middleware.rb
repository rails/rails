module ActionController
  class Middleware < Metal
    class ActionMiddleware
      def initialize(controller)
        @controller = controller
      end

      def call(env)
        controller = @controller.allocate
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
      process(:index)
    end
    
    def index
      call(env)
    end
  end
end
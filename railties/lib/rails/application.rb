module Rails
  class Application
    def initialize
      @app = ActionController::Dispatcher.new
    end

    def call(env)
      @app.call(env)
    end
  end
end

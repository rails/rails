module ActionDispatch
  class Reloader
    def initialize(app)
      @app = app
    end

    def call(env)
      ActionController::Dispatcher.reload_application
      @app.call(env)
    ensure
      ActionController::Dispatcher.cleanup_application
    end
  end
end

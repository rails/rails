module ActionController
  class Reloader
    def initialize(app)
      @app = app
    end

    def call(env)
      Dispatcher.reload_application
      @app.call(env)
    ensure
      Dispatcher.cleanup_application
    end
  end
end

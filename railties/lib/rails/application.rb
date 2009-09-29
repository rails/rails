module Rails
  class Application
    attr_accessor :config

    def self.load(environment_file)
      environment = File.read(environment_file)
      Object.class_eval(environment, environment_file)
    end

    def routes
      ActionController::Routing::Routes
    end

    def middleware
      config.middleware
    end

    def call(env)
      @app ||= middleware.build(@routes)
      @app.call(env)
    end
  end
end

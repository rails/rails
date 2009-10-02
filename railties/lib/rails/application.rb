module Rails
  class Application

    def self.config
      @config ||= Configuration.new
    end

    def self.config=(config)
      @config = config
    end

    def config
      self.class.config
    end

    def routes
      ActionController::Routing::Routes
    end

    def middleware
      config.middleware
    end

    def call(env)
      @app ||= middleware.build(routes)
      @app.call(env)
    end
  end
end

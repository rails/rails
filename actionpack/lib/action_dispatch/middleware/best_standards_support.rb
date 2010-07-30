module ActionDispatch
  class BestStandardsSupport
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers["X-UA-Compatible"] = "IE=Edge,chrome=1"
      [status, headers, body]
    end
  end
end

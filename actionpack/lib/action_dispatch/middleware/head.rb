module ActionDispatch
  class Head
    def initialize(app)
      @app = app
    end

    def call(env)
      if env["REQUEST_METHOD"] == "HEAD"
        env["REQUEST_METHOD"] = "GET"
        env["rack.methodoverride.original_method"] = "HEAD"
        status, headers, _ = @app.call(env)
        [status, headers, []]
      else
        @app.call(env)
      end
    end
  end
end

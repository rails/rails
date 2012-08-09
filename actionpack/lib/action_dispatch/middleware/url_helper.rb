module ActionDispatch
  class UrlHelper

    def initialize(app)
      @app = app
    end

    def call(env)
      req = ActionDispatch::Request.new(env)
      Thread.current["ActionDispatch::UrlHelper.host"] = req.host
      Thread.current["ActionDispatch::UrlHelper.port"] = req.optional_port
      Thread.current["ActionDispatch::UrlHelper.protocol"] = req.protocol
      @app.call(env)
    end
  end
end
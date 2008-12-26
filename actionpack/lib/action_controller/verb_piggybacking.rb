module ActionController
  # TODO: Use Rack::MethodOverride when it is released
  class VerbPiggybacking
    HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS)

    def initialize(app)
      @app = app
    end

    def call(env)
      if env["REQUEST_METHOD"] == "POST"
        req = Request.new(env)
        if method = (req.parameters[:_method] || env["HTTP_X_HTTP_METHOD_OVERRIDE"])
          method = method.to_s.upcase
          if HTTP_METHODS.include?(method)
            env["REQUEST_METHOD"] = method
          end
        end
      end

      @app.call(env)
    end
  end
end

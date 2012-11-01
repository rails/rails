module ActionDispatch
  class BestStandardsSupport
    def initialize(app, type = true)
      @app = app

      @header = case type
      when true
        "IE=Edge,chrome=1"
      when :builtin
        "IE=Edge"
      when false
        nil
      end
    end

    def call(env)
      status, headers, body = @app.call(env)

      if headers["X-UA-Compatible"] && @header
        headers["X-UA-Compatible"] << "," << @header.to_s
      else
        headers["X-UA-Compatible"] = @header
      end

      [status, headers, body]
    end
  end
end

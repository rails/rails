require 'rack/body_proxy'

module ActionDispatch
  class Executor
    def initialize(app, executor)
      @app, @executor = app, executor
    end

    def call(env)
      state = @executor.run!
      begin
        response = @app.call(env)
        returned = response << ::Rack::BodyProxy.new(response.pop) { state.complete!(env: env) }
      ensure
        state.complete!(env: env) unless returned
      end
    end
  end
end

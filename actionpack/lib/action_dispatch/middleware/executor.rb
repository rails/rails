require 'rack/body_proxy'

module ActionDispatch
  class Executor
    def initialize(app, executor)
      @app, @executor = app, executor
    end

    def call(env)
      @executor.instance_variable_set('@rack_test', env['rack.test'])
      state = @executor.run!
      begin
        response = @app.call(env)
        returned = response << ::Rack::BodyProxy.new(response.pop) { state.complete! }
      ensure
        state.complete! unless returned
      end
    end
  end
end

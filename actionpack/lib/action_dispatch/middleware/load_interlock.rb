require 'active_support/dependencies'
require 'rack/body_proxy'

module ActionDispatch
  class LoadInterlock
    def initialize(app)
      @app = app
    end

    def call(env)
      interlock = ActiveSupport::Dependencies.interlock
      interlock.start_running
      response = @app.call(env)
      body = Rack::BodyProxy.new(response[2]) { interlock.done_running }
      response[2] = body
      response
    ensure
      interlock.done_running unless body
    end
  end
end

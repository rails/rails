# frozen_string_literal: true

module ActionDispatch
  # Makes the current Rack env available via ActionDispatch::Current.rack_env.
  # Used by ApplicationController.renderer.current to provide a renderer
  # instance for the current request's Rack environment.
  #
  # (Must be inserted after the Executor middleware, since that manages the
  # ActiveSupport::CurrentAttributes lifecycle.)
  class CurrentRackEnv # :nodoc:
    def initialize(app)
      @app = app
    end

    def call(env)
      ::ActionDispatch::Current.rack_env = env
      @app.call env
    end
  end
end

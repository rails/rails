module ActionDispatch
  class Rescue
    def initialize(app, rescuer)
      @app, @rescuer = app, rescuer
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      env['action_dispatch.rescue.exception'] = exception
      @rescuer.call(env)
    end
  end
end

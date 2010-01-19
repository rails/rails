module ActionDispatch
  # Provide notifications in the middleware stack. Notice that for the before_dispatch
  # and after_dispatch notifications, we just send the original env, so we don't pile
  # up large env hashes in the queue. However, in exception cases, the whole env hash
  # is actually useful, so we send it all.
  class Notifications
    def initialize(app)
      @app = app
    end

    def call(stack_env)
      env = stack_env.dup
      ActiveSupport::Notifications.instrument("action_dispatch.before_dispatch", :env => env)

      ActiveSupport::Notifications.instrument!("action_dispatch.after_dispatch", :env => env) do
        @app.call(stack_env)
      end
    rescue Exception => exception
      ActiveSupport::Notifications.instrument('action_dispatch.exception',
        :env => stack_env, :exception => exception)
      raise exception
    end
  end
end
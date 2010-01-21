module ActionDispatch
  # Provide notifications in the middleware stack. Notice that for the before_dispatch
  # and after_dispatch notifications, we just send the original env, so we don't pile
  # up large env hashes in the queue. However, in exception cases, the whole env hash
  # is actually useful, so we send it all.
  class Notifications
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Request.new(env)
      payload = retrieve_payload_from_env(request.filter_env)

      ActiveSupport::Notifications.instrument("action_dispatch.before_dispatch", payload)

      ActiveSupport::Notifications.instrument!("action_dispatch.after_dispatch", payload) do
        @app.call(env)
      end
    rescue Exception => exception
      ActiveSupport::Notifications.instrument('action_dispatch.exception',
        :env => env, :exception => exception)
      raise exception
    end

    protected
      # Remove any rack related constants from the env, like rack.input.
      def retrieve_payload_from_env(env)
        Hash[:env => env.except(*env.keys.select { |k| k.to_s.index("rack.") == 0 })]
      end
  end
end

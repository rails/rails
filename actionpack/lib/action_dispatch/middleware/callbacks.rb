
module ActionDispatch
  # Provide callbacks to be executed before and after the request dispatch.
  class Callbacks
    include ActiveSupport::Callbacks

    define_callbacks :call

    class << self
      delegate :to_prepare, :to_cleanup, :to => "ActionDispatch::Reloader"

      def before(*args, &block)
        set_callback(:call, :before, *args, &block)
      end

      def after(*args, &block)
        set_callback(:call, :after, *args, &block)
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      error = nil
      result = run_callbacks :call do
        begin
          @app.call(env)
        rescue => error
        end
      end
      raise error if error
      result
    end
  end
end

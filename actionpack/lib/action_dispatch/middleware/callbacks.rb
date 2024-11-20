# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # # Action Dispatch Callbacks
  #
  # Provides callbacks to be executed before and after dispatching the request.
  class Callbacks
    include ActiveSupport::Callbacks

    define_callbacks :call

    class << self
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
        @app.call(env)
      rescue => error
      end
      raise error if error
      result
    end
  end
end

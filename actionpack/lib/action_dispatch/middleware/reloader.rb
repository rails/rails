module ActionDispatch
  # ActionDispatch::Reloader provides prepare and cleanup callbacks,
  # intended to assist with code reloading during development.
  #
  # Prepare callbacks are run before each request, and cleanup callbacks
  # after each request. In this respect they are analogs of ActionDispatch::Callback's
  # before and after callbacks. However, cleanup callbacks are not called until the
  # request is fully complete -- that is, after #close has been called on
  # the response body. This is important for streaming responses such as the
  # following:
  #
  #     self.response_body = lambda { |response, output|
  #       # code here which refers to application models
  #     }
  #
  # Cleanup callbacks will not be called until after the response_body lambda
  # is evaluated, ensuring that it can refer to application models and other
  # classes before they are unloaded.
  #
  # By default, ActionDispatch::Reloader is included in the middleware stack
  # only in the development environment; specifically, when config.cache_classes
  # is false. Callbacks may be registered even when it is not included in the
  # middleware stack, but are executed only when +ActionDispatch::Reloader.prepare!+
  # or +ActionDispatch::Reloader.cleanup!+ are called manually.
  #
  class Reloader
    include ActiveSupport::Callbacks

    define_callbacks :prepare, :scope => :name
    define_callbacks :cleanup, :scope => :name

    # Add a prepare callback. Prepare callbacks are run before each request, prior
    # to ActionDispatch::Callback's before callbacks.
    def self.to_prepare(*args, &block)
      set_callback(:prepare, *args, &block)
    end

    # Add a cleanup callback. Cleanup callbacks are run after each request is
    # complete (after #close is called on the response body).
    def self.to_cleanup(*args, &block)
      set_callback(:cleanup, *args, &block)
    end

    # Execute all prepare callbacks.
    def self.prepare!
      new(nil).run_callbacks :prepare
    end

    # Execute all cleanup callbacks.
    def self.cleanup!
      new(nil).run_callbacks :cleanup
    end

    def initialize(app)
      @app = app
    end

    module CleanupOnClose
      def close
        super if defined?(super)
      ensure
        ActionDispatch::Reloader.cleanup!
      end
    end

    def call(env)
      run_callbacks :prepare
      response = @app.call(env)
      response[2].extend(CleanupOnClose)
      response
    rescue Exception
      run_callbacks :cleanup
      raise
    end
  end
end

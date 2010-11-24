module ActionDispatch
  # ActionDispatch::Reloader provides to_prepare and to_cleanup callbacks.
  # These are analogs of ActionDispatch::Callback's before and after
  # callbacks, with the difference that to_cleanup is not called until the
  # request is fully complete -- that is, after #close has been called on
  # the request body. This is important for streaming responses such as the
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
  # only in the development environment.
  #
  class Reloader
    include ActiveSupport::Callbacks

    define_callbacks :prepare, :scope => :name
    define_callbacks :cleanup, :scope => :name

    # Add a preparation callback. Preparation callbacks are run before each
    # request.
    #
    # If a symbol with a block is given, the symbol is used as an identifier.
    # That allows to_prepare to be called again with the same identifier to
    # replace the existing callback. Passing an identifier is a suggested
    # practice if the code adding a preparation block may be reloaded.
    def self.to_prepare(*args, &block)
      first_arg = args.first
      if first_arg.is_a?(Symbol) && block_given?
        remove_method :"__#{first_arg}" if method_defined?(:"__#{first_arg}")
        define_method :"__#{first_arg}", &block
        set_callback(:prepare, :"__#{first_arg}")
      else
        set_callback(:prepare, *args, &block)
      end
    end

    # Add a cleanup callback. Cleanup callbacks are run after each request is
    # complete (after #close is called on the response body).
    def self.to_cleanup(&block)
      set_callback(:cleanup, &block)
    end

    def self.prepare!
      new(nil).send(:_run_prepare_callbacks)
    end

    def self.cleanup!
      new(nil).send(:_run_cleanup_callbacks)
    end

    def self.reload!
      prepare!
      cleanup!
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
      _run_prepare_callbacks
      response = @app.call(env)
      response[2].extend(CleanupOnClose)
      response
    end
  end
end

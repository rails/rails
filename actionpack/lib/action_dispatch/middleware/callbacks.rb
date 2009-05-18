module ActionDispatch
  class Callbacks
    include ActiveSupport::Callbacks
    define_callbacks :prepare, :before, :after

    class << self
      # DEPRECATED
      alias_method :prepare_dispatch, :prepare
      alias_method :before_dispatch, :before
      alias_method :after_dispatch, :after
    end

    # Add a preparation callback. Preparation callbacks are run before every
    # request in development mode, and before the first request in production
    # mode.
    #
    # An optional identifier may be supplied for the callback. If provided,
    # to_prepare may be called again with the same identifier to replace the
    # existing callback. Passing an identifier is a suggested practice if the
    # code adding a preparation block may be reloaded.
    def self.to_prepare(identifier = nil, &block)
      @prepare_callbacks ||= ActiveSupport::Callbacks::CallbackChain.new
      callback = ActiveSupport::Callbacks::Callback.new(:prepare, block, :identifier => identifier)
      @prepare_callbacks.replace_or_append!(callback)
    end

    def initialize(app, prepare_each_request = false)
      @app, @prepare_each_request = app, prepare_each_request
      run_callbacks :prepare
    end

    def call(env)
      run_callbacks :before
      run_callbacks :prepare if @prepare_each_request
      @app.call(env)
    ensure
      run_callbacks :after, :enumerator => :reverse_each
    end
  end
end

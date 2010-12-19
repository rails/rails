module ActionDispatch
  # Provide callbacks to be executed before and after the request dispatch.
  class Callbacks
    include ActiveSupport::Callbacks

    define_callbacks :call, :rescuable => true

    def self.to_prepare(*args, &block)
      ActiveSupport::Deprecation.warn "ActionDispatch::Callbacks.to_prepare is deprecated. " <<
        "Please use ActionDispatch::Reloader.to_prepare instead."
      ActionDispatch::Reloader.to_prepare(*args, &block)
    end

    def self.before(*args, &block)
      set_callback(:call, :before, *args, &block)
    end

    def self.after(*args, &block)
      set_callback(:call, :after, *args, &block)
    end

    def initialize(app, unused = nil)
      ActiveSupport::Deprecation.warn "Passing a second argument to ActionDispatch::Callbacks.new is deprecated." unless unused.nil?
      @app = app
    end

    def call(env)
      _run_call_callbacks do
        @app.call(env)
      end
    end
  end
end

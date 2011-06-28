require 'active_support/core_ext/module/delegation'

module ActionDispatch
  # Provide callbacks to be executed before and after the request dispatch.
  class Callbacks
    include ActiveSupport::Callbacks

    define_callbacks :call, :rescuable => true

    class << self
      delegate :to_prepare, :to_cleanup, :to => "ActionDispatch::Reloader"
    end

    def self.before(*args, &block)
      set_callback(:call, :before, *args, &block)
    end

    def self.after(*args, &block)
      set_callback(:call, :after, *args, &block)
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      run_callbacks :call do
        @app.call(env)
      end
    end
  end
end

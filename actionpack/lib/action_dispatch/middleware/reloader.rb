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
  #     self.response_body = -> (response, output) do
  #       # code here which refers to application models
  #     end
  #
  # Cleanup callbacks will not be called until after the response_body lambda
  # is evaluated, ensuring that it can refer to application models and other
  # classes before they are unloaded.
  #
  # By default, ActionDispatch::Reloader is included in the middleware stack
  # only in the development environment; specifically, when +config.cache_classes+
  # is false. Callbacks may be registered even when it is not included in the
  # middleware stack, but are executed only when <tt>ActionDispatch::Reloader.prepare!</tt>
  # or <tt>ActionDispatch::Reloader.cleanup!</tt> are called manually.
  #
  class Reloader < Executor
    def self.to_prepare(*args, &block)
      ActiveSupport::Reloader.to_prepare(*args, &block)
    end

    def self.to_cleanup(*args, &block)
      ActiveSupport::Reloader.to_complete(*args, &block)
    end

    def self.prepare!
      default_reloader.prepare!
    end

    def self.cleanup!
      default_reloader.reload!
    end

    class << self
      attr_accessor :default_reloader # :nodoc:

      deprecate to_prepare: "use ActiveSupport::Reloader.to_prepare instead",
        to_cleanup: "use ActiveSupport::Reloader.to_complete instead",
        prepare!: "use Rails.application.reloader.prepare! instead",
        cleanup!: "use Rails.application.reloader.reload! instead of cleanup + prepare"
    end

    self.default_reloader = ActiveSupport::Reloader
  end
end

# frozen_string_literal: true

# :markup: markdown

require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  # # Action Dispatch MiddlewareStack
  #
  # Read more about [Rails middleware
  # stack](https://guides.rubyonrails.org/rails_on_rack.html#action-dispatcher-middleware-stack)
  # in the guides.
  class MiddlewareStack < ActiveSupport::MiddlewareStack
    class Middleware < ActiveSupport::MiddlewareStack::Middleware
      def build_instrumented(app)
        InstrumentationProxy.new(build(app), inspect)
      end
    end

    # This class is used to instrument the execution of a single middleware. It
    # proxies the `call` method transparently and instruments the method call.
    class InstrumentationProxy
      EVENT_NAME = "process_middleware.action_dispatch"

      def initialize(middleware, class_name)
        @middleware = middleware

        @payload = {
          middleware: class_name,
        }
      end

      def call(env)
        ActiveSupport::Notifications.instrument(EVENT_NAME, @payload) do
          @middleware.call(env)
        end
      end
    end

    def build(app = nil, &block)
      instrumenting = ActiveSupport::Notifications.notifier.listening?(InstrumentationProxy::EVENT_NAME)
      middlewares.freeze.reverse.inject(app || block) do |a, e|
        if instrumenting
          e.build_instrumented(a)
        else
          e.build(a)
        end
      end
    end

    private
      def build_middleware(klass, args, block)
        Middleware.new(klass, args, block)
      end
  end
end

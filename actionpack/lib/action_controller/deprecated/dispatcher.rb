module ActionController
  class Dispatcher
    class << self
      def before_dispatch(*args, &block)
        ActiveSupport::Deprecation.warn "ActionController::Dispatcher.before_dispatch is deprecated. " <<
          "Please use ActionDispatch::Callbacks.before instead.", caller
        ActionDispatch::Callbacks.before(*args, &block)
      end

      def after_dispatch(*args, &block)
        ActiveSupport::Deprecation.warn "ActionController::Dispatcher.after_dispatch is deprecated. " <<
          "Please use ActionDispatch::Callbacks.after instead.", caller
        ActionDispatch::Callbacks.after(*args, &block)
      end

      def to_prepare(*args, &block)
        ActiveSupport::Deprecation.warn "ActionController::Dispatcher.to_prepare is deprecated. " <<
          "Please use config.to_prepare instead", caller
        ActionDispatch::Callbacks.after(*args, &block)
      end

      def new
        ActiveSupport::Deprecation.warn "ActionController::Dispatcher.new is deprecated, use Rails.application instead."
        Rails.application
      end
    end
  end
end

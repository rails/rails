module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    extend ActiveSupport::Concern

    included do
      self.config.session_store   ||= :cookie_store
      self.config.session_options ||= {}
    end

    module ClassMethods
      def session_options
        config.session_options
      end

      def session_store
        case store = config.session_store
        when :active_record_store
          ActiveRecord::SessionStore
        when Symbol
          ActionDispatch::Session.const_get(store.to_s.camelize)
        else
          store
        end
      end

      def session=(options = {})
        self.session_store = nil if options.delete(:disabled)
        session_options.merge!(options)
      end

      def session(*args)
        ActiveSupport::Deprecation.warn(
          "Disabling sessions for a single controller has been deprecated. " +
          "Sessions are now lazy loaded. So if you don't access them, " +
          "consider them off. You can still modify the session cookie " +
          "options with request.session_options.", caller)
      end
    end
  end
end

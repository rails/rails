module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    extend ActiveSupport::Concern

    included do
      self.config.session_store   ||= :cookie_store
      self.config.session_options ||= {}
    end

    module ClassMethods
      # Set the session store to be used for keeping the session data between requests.
      # By default, sessions are stored in browser cookies (<tt>:cookie_store</tt>),
      # but you can also specify one of the other included stores (<tt>:active_record_store</tt>,
      # <tt>:mem_cache_store</tt>, or your own custom class.
      def session_store=(store)
        ActiveSupport::Deprecation.warn "Setting session_store directly on ActionController::Base is deprecated. " \
                                        "Please set it on config.action_controller.session_store"
        config.session_store = store
      end

      def session_options=(opts)
        ActiveSupport::Deprecation.warn "Setting seession_options directly on ActionController::Base is deprecated. " \
                                        "Please set it on config.action_controller.session_options"
        config.session_store = opts
      end

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

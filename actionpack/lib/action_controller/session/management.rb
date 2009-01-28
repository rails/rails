module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    def self.included(base)
      base.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      # Set the session store to be used for keeping the session data between requests.
      # By default, sessions are stored in browser cookies (<tt>:cookie_store</tt>),
      # but you can also specify one of the other included stores (<tt>:active_record_store</tt>,
      # <tt>:mem_cache_store</tt>, or your own custom class.
      def session_store=(store)
        if store == :active_record_store
          self.session_store = ActiveRecord::SessionStore
        else
          @@session_store = store.is_a?(Symbol) ?
            Session.const_get(store.to_s.camelize) :
            store
        end
      end

      # Returns the session store class currently used.
      def session_store
        if defined? @@session_store
          @@session_store
        else
          Session::CookieStore
        end
      end

      def session=(options = {})
        self.session_store = nil if options.delete(:disabled)
        session_options.merge!(options)
      end

      # Returns the hash used to configure the session. Example use:
      #
      #   ActionController::Base.session_options[:secure] = true # session only available over HTTPS
      def session_options
        @session_options ||= {}
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

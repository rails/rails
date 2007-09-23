module ActionController #:nodoc:
  class InvalidToken < ActionControllerError; end

  # Protect a controller's actions with the #verify_token method.  Failure to validate will result in a ActionController::InvalidToken 
  # exception.  Customize the error message through the use of rescue_templates and rescue_action_in_public.
  #
  #   class FooController < ApplicationController
  #     # uses the cookie session store
  #     verify_token :except => :index
  #
  #     # uses one of the other session stores that uses a session_id value.
  #     verify_token :secret => 'my-little-pony', :except => :index
  #   end
  #
  # Valid Options:
  #
  # * <tt>:only/:except</tt> - passed to the before_filter call.  Set which actions are verified.
  # * <tt>:secret</tt> - Custom salt used to generate the form_token.  Leave this off if you are using the cookie session store.
  # * <tt>:digest</tt> - Message digest used for hashing.  Defaults to 'SHA1'
  module RequestForgeryProtection
    def self.included(base)
      base.class_eval do
        class_inheritable_accessor :verify_token_options
        self.verify_token_options = {}
        helper_method :form_token
      end
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def verify_token(options = {})
        self.request_forgery_protection_token ||= :_token
        before_filter :verify_request_token, :only => options.delete(:only), :except => options.delete(:except)
        verify_token_options.update(options)
      end
    end

    protected
      # The actual before_filter that is used.  Modify this to change how you handle unverified requests.
      def verify_request_token
        verified_request? || raise(ActionController::InvalidToken)
      end
      
      # Returns true or false if a request is verified.  Checks:
      #
      # * is the format restricted?  By default, only HTML and AJAX requests are checked.
      # * is it a GET request?  Gets should be safe and idempotent
      # * Does the form_token match the given _token value from the params?
      def verified_request?
        request_forgery_protection_token.nil? || request.method == :get || !verifiable_request_format? || form_token == params[request_forgery_protection_token]
      end
    
      def verifiable_request_format?
        request.format.html? || request.format.js?
      end
    
      # Sets the token value for the current session.  Pass a :secret option in #verify_token to add a custom salt to the hash.
      def form_token
        @form_token ||= verify_token_options[:secret] ? token_from_session_id : token_from_cookie_session
      end
      
      # Generates a unique digest using the session_id and the CSRF secret.
      def token_from_session_id
        key    = verify_token_options[:secret].respond_to?(:call) ? verify_token_options[:secret].call(@session) : verify_token_options[:secret]
        digest = verify_token_options[:digest] || 'SHA1'
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new(digest), key.to_s, session.session_id.to_s)
      end
      
      # No secret was given, so assume this is a cookie session store.
      def token_from_cookie_session
        session[:csrf_id] ||= CGI::Session.generate_unique_id
        session.dbman.generate_digest(session[:csrf_id])
      end
  end
end
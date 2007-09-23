module ActionController #:nodoc:
  class InvalidToken < ActionControllerError; end

  # Protect a controller's actions with the #protect_from_forgery method.  Failure to validate will result in a ActionController::InvalidToken 
  # exception.  Customize the error message through the use of rescue_templates and rescue_action_in_public.
  #
  #   class FooController < ApplicationController
  #     # uses the cookie session store
  #     protect_from_forgery :except => :index
  #
  #     # uses one of the other session stores that uses a session_id value.
  #     protect_from_forgery :secret => 'my-little-pony', :except => :index
  #   end
  #
  # Valid Options:
  #
  # * <tt>:only/:except</tt> - passed to the before_filter call.  Set which actions are verified.
  # * <tt>:secret</tt> - Custom salt used to generate the form_authenticity_token.  Leave this off if you are using the cookie session store.
  # * <tt>:digest</tt> - Message digest used for hashing.  Defaults to 'SHA1'
  module RequestForgeryProtection
    def self.included(base)
      base.class_eval do
        class_inheritable_accessor :request_forgery_protection_options
        self.request_forgery_protection_options = {}
        helper_method :form_authenticity_token
      end
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def protect_from_forgery(options = {})
        self.request_forgery_protection_token ||= :authenticity_token
        before_filter :verify_authenticity_token, :only => options.delete(:only), :except => options.delete(:except)
        request_forgery_protection_options.update(options)
      end
    end

    protected
      # The actual before_filter that is used.  Modify this to change how you handle unverified requests.
      def verify_authenticity_token
        verified_request? || raise(ActionController::InvalidToken)
      end
      
      # Returns true or false if a request is verified.  Checks:
      #
      # * is the format restricted?  By default, only HTML and AJAX requests are checked.
      # * is it a GET request?  Gets should be safe and idempotent
      # * Does the form_authenticity_token match the given _token value from the params?
      def verified_request?
        request_forgery_protection_token.nil? ||
          request.method == :get              ||
          !verifiable_request_format?         ||
          form_authenticity_token == params[request_forgery_protection_token]
      end
    
      def verifiable_request_format?
        request.format.html? || request.format.js?
      end
    
      # Sets the token value for the current session.  Pass a :secret option in #verify_token to add a custom salt to the hash.
      def form_authenticity_token
        @form_authenticity_token ||= if request_forgery_protection_options[:secret]
          authenticity_token_from_session_id
        else
          authenticity_token_from_cookie_session
        end
      end
      
      # Generates a unique digest using the session_id and the CSRF secret.
      def authenticity_token_from_session_id
        key = if request_forgery_protection_options[:secret].respond_to?(:call)
          request_forgery_protection_options[:secret].call(@session)
        else
          request_forgery_protection_options[:secret]
        end
        digest = request_forgery_protection_options[:digest] ||= 'SHA1'
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new(digest), key.to_s, session.session_id.to_s)
      end
      
      # No secret was given, so assume this is a cookie session store.
      def authenticity_token_from_cookie_session
        session[:csrf_id] ||= CGI::Session.generate_unique_id
        session.dbman.generate_digest(session[:csrf_id])
      end
  end
end
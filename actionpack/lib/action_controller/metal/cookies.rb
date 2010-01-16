module ActionController #:nodoc:
  module Cookies
    extend ActiveSupport::Concern

    include RackDelegation

    included do
      helper_method :cookies
      cattr_accessor :cookie_verifier_secret
    end
    
    private
      def cookies
        request.cookie_jar
      end
  end
end

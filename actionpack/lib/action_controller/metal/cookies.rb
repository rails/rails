module ActionController #:nodoc:
  module Cookies
    extend ActiveSupport::Concern

    include RackDelegation

    included do
      helper_method :cookies
    end

    private
      def cookies
        raise "You must set config.cookie_secret in your app's config" if config.secret.blank?
        request.cookie_jar(:signing_secret => config.secret)
      end
  end
end

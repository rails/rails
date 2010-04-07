module ActionController #:nodoc:
  module Cookies
    extend ActiveSupport::Concern

    include RackDelegation

    included do
      helper_method :cookies
    end

    private
      def cookies
        request.cookie_jar
      end
  end
end

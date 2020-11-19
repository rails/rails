# frozen_string_literal: true

module ActionController #:nodoc:
  module Cookies
    extend ActiveSupport::Concern

    included do
      helper_method :cookies if defined?(helper_method)
    end

    private
      # The cookies for the current request. See ActionDispatch::Cookies for
      # more information.
      def cookies # :doc:
        request.cookie_jar
      end
  end
end

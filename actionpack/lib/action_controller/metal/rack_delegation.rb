require 'action_dispatch/http/request'
require 'action_dispatch/http/response'

module ActionController
  module RackDelegation
    extend ActiveSupport::Concern

    delegate :headers, :status=, :location=, :content_type=,
             :status, :location, :content_type, :response_code, :to => "@_response"

    module ClassMethods
      def build_with_env(env = {}) #:nodoc:
        new.tap { |c| c.set_request! ActionDispatch::Request.new(env) }
      end
    end

    def reset_session
      @_request.reset_session
    end
  end
end

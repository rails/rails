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

    def set_request!(request) #:nodoc:
      super
      set_response!(request)
    end

    def response_body=(body)
      response.body = body if response
      super
    end

    def reset_session
      @_request.reset_session
    end

    private

    def set_response!(request)
      @_response         = ActionDispatch::Response.new
      @_response.request = request
    end
  end
end

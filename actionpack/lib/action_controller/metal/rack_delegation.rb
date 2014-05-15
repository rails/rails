require 'action_dispatch/http/request'
require 'action_dispatch/http/response'

module ActionController
  module RackDelegation
    extend ActiveSupport::Concern

    delegate :headers, :status=, :location=, :content_type=,
             :status, :location, :content_type, :_status_code, :to => "@_response"

    def dispatch(action, request)
      set_response!(request)
      super(action, request)
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

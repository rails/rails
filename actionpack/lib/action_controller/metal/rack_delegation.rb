require 'action_dispatch/http/request'
require 'action_dispatch/http/response'

module ActionController
  module RackDelegation
    extend ActiveSupport::Concern

    delegate :headers, :status=, :location=, :content_type=,
             :status, :location, :content_type, :to => "@_response"

    def dispatch(action, request, response = ActionDispatch::Response.new)
      @_response ||= response
      @_response.request ||= request
      super(action, request)
    end

    def response_body=(body)
      response.body = body if response
      super
    end

    def reset_session
      @_request.reset_session
    end
  end
end

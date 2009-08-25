module ActionController
  module RackConvenience
    extend ActiveSupport::Concern

    included do
      delegate :headers, :status=, :location=, :content_type=,
               :status, :location, :content_type, :to => "@_response"
      attr_internal :request
    end

    def call(name, env)
      @_request = ActionDispatch::Request.new(env)
      @_response = ActionDispatch::Response.new
      @_response.request = request
      super
    end

    def params
      @_params ||= @_request.parameters
    end

    def response_body=(body)
      response.body = body if response
      super
    end
  end
end

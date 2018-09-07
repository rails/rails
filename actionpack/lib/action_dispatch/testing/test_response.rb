# frozen_string_literal: true

require "action_dispatch/testing/request_encoder"

module ActionDispatch
  # Integration test methods such as ActionDispatch::Integration::Session#get
  # and ActionDispatch::Integration::Session#post return objects of class
  # TestResponse, which represent the HTTP response results of the requested
  # controller actions.
  #
  # See Response for more information on controller response objects.
  class TestResponse < Response
    def self.from_response(response)
      new response.status, response.headers, response.body
    end

    def initialize(*) # :nodoc:
      super
      @response_parser = RequestEncoder.parser(content_type)
    end

    # Was the response successful?
    def success?
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
       The success? predicate is deprecated and will be removed in Rails 6.0.
       Please use successful? as provided by Rack::Response::Helpers.
      MSG
      successful?
    end

    # Was the URL not found?
    def missing?
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
       The missing? predicate is deprecated and will be removed in Rails 6.0.
       Please use not_found? as provided by Rack::Response::Helpers.
      MSG
      not_found?
    end

    # Was there a server-side error?
    def error?
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
       The error? predicate is deprecated and will be removed in Rails 6.0.
       Please use server_error? as provided by Rack::Response::Helpers.
      MSG
      server_error?
    end

    def parsed_body
      @parsed_body ||= @response_parser.call(body)
    end
  end
end

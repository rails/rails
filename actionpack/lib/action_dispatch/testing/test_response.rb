# frozen_string_literal: true

require 'action_dispatch/testing/request_encoder'

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

    def parsed_body
      @parsed_body ||= response_parser.call(body)
    end

    def response_parser
      @response_parser ||= RequestEncoder.parser(media_type)
    end
  end
end

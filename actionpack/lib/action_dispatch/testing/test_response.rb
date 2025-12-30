# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/testing/request_encoder"

module ActionDispatch
  # Integration test methods such as Integration::RequestHelpers#get and
  # Integration::RequestHelpers#post return objects of class TestResponse, which
  # represent the HTTP response results of the requested controller actions.
  #
  # See Response for more information on controller response objects.
  class TestResponse < Response
    def self.from_response(response)
      new response.status, response.headers, response.body
    end

    # Returns a parsed body depending on the response MIME type. When a parser
    # corresponding to the MIME type is not found, it returns the raw body.
    #
    # #### Examples
    #     get "/posts"
    #     response.content_type         # => "text/html; charset=utf-8"
    #     response.parsed_body.class    # => Nokogiri::HTML5::Document
    #     response.parsed_body.to_html  # => "<!DOCTYPE html>\n<html>\n..."
    #
    #     assert_pattern { response.parsed_body.at("main") => { content: "Hello, world" } }
    #
    #     response.parsed_body.at("main") => {name:, content:}
    #     assert_equal "main", name
    #     assert_equal "Some main content", content
    #
    #     get "/posts.json"
    #     response.content_type         # => "application/json; charset=utf-8"
    #     response.parsed_body.class    # => Array
    #     response.parsed_body          # => [{"id"=>42, "title"=>"Title"},...
    #
    #     assert_pattern { response.parsed_body => [{ id: 42 }] }
    #
    #     get "/posts/42.json"
    #     response.content_type         # => "application/json; charset=utf-8"
    #     response.parsed_body.class    # => ActiveSupport::HashWithIndifferentAccess
    #     response.parsed_body          # => {"id"=>42, "title"=>"Title"}
    #
    #     assert_pattern { response.parsed_body => [{ title: /title/i }] }
    #
    #     response.parsed_body => {id:, title:}
    #     assert_equal 42, id
    #     assert_equal "Title", title
    def parsed_body
      @parsed_body ||= response_parser.call(body)
    end

    def response_parser
      @response_parser ||= RequestEncoder.parser(media_type)
    end
  end
end

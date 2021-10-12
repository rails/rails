# frozen_string_literal: true

require "rails-dom-testing"
require "action_dispatch/testing/assertions/response"
require "action_dispatch/testing/assertions/routing"

module ActionDispatch
  module Assertions
    include ResponseAssertions
    include RoutingAssertions
    include Rails::Dom::Testing::Assertions

    def html_document
      @html_document ||= if @response.media_type&.end_with?("xml")
        Nokogiri::XML::Document.parse(@response.body)
      else
        Nokogiri::HTML::Document.parse(@response.body)
      end
    end
  end
end

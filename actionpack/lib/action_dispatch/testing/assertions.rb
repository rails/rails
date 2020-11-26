# frozen_string_literal: true

require "rails-dom-testing"

module ActionDispatch
  module Assertions
    autoload :ResponseAssertions, "action_dispatch/testing/assertions/response"
    autoload :RoutingAssertions, "action_dispatch/testing/assertions/routing"

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

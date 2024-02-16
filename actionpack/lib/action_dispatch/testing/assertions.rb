# frozen_string_literal: true

# :markup: markdown

require "rails-dom-testing"
require "action_dispatch/testing/assertions/response"
require "action_dispatch/testing/assertions/routing"

module ActionDispatch
  module Assertions
    extend ActiveSupport::Concern

    include ResponseAssertions
    include RoutingAssertions
    include Rails::Dom::Testing::Assertions

    def html_document
      @html_document ||= if @response.media_type&.end_with?("xml")
        Nokogiri::XML::Document.parse(@response.body)
      else
        Rails::Dom::Testing.html_document.parse(@response.body)
      end
    end
  end
end

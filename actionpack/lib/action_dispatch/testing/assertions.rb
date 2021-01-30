# frozen_string_literal: true

require "capybara/minitest"
require "rails-dom-testing"
require "action_dispatch/testing/assertions/response"
require "action_dispatch/testing/assertions/routing"

module ActionDispatch
  module Assertions
    include ResponseAssertions
    include RoutingAssertions
    include Rails::Dom::Testing::Assertions
    alias_method :assert_dom, :assert_select
    include Capybara::Minitest::Assertions

    def page
      integration_session.page
    end

    def within(*arguments, **options, &block)
      page.within(*arguments, **options, &block)
    end

    def html_document
      @html_document ||= if @response.media_type&.end_with?("xml")
        Nokogiri::XML::Document.parse(@response.body)
      else
        Nokogiri::HTML::Document.parse(@response.body)
      end
    end
  end
end

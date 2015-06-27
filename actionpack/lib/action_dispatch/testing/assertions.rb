require 'rails-dom-testing'

module ActionDispatch
  module Assertions
    autoload :ResponseAssertions, 'action_dispatch/testing/assertions/response'
    autoload :RoutingAssertions, 'action_dispatch/testing/assertions/routing'

    extend ActiveSupport::Concern

    include ResponseAssertions
    include RoutingAssertions
    include Rails::Dom::Testing::Assertions

    def html_document
      @html_document ||= if @response.content_type.to_s =~ /xml$/
        Nokogiri::XML::Document.parse(@response.body)
      else
        Nokogiri::HTML::Document.parse(@response.body)
      end
    end
  end
end

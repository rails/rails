require 'action_view/vendor/html-scanner'

module ActionDispatch
  module Assertions
    module DomAssertions
      # \Test two HTML strings for equivalency (e.g., identical up to reordering of attributes)
      #
      #   # assert that the referenced method generates the appropriate HTML string
      #   assert_dom_equal '<a href="http://www.example.com">Apples</a>', link_to("Apples", "http://www.example.com")
      def assert_dom_equal(expected, actual, message = "")
        expected_dom = HTML::Document.new(expected).root
        actual_dom   = HTML::Document.new(actual).root
        assert_equal expected_dom, actual_dom
      end

      # The negated form of +assert_dom_equivalent+.
      #
      #   # assert that the referenced method does not generate the specified HTML string
      #   assert_dom_not_equal '<a href="http://www.example.com">Apples</a>', link_to("Oranges", "http://www.example.com")
      def assert_dom_not_equal(expected, actual, message = "")
        expected_dom = HTML::Document.new(expected).root
        actual_dom   = HTML::Document.new(actual).root
        refute_equal expected_dom, actual_dom
      end
    end
  end
end

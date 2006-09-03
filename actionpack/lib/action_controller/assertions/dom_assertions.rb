module ActionController
  module Assertions
    module DomAssertions
      # test 2 html strings to be equivalent, i.e. identical up to reordering of attributes
      def assert_dom_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be == to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom == actual_dom }
        end
      end
      
      # negated form of +assert_dom_equivalent+
      def assert_dom_not_equal(expected, actual, message="")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom   = HTML::Document.new(actual).root
          full_message = build_message(message, "<?> expected to be != to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom != actual_dom }
        end
      end
    end
  end
end
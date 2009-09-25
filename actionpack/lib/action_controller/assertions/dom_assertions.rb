module ActionController
  module Assertions
    module DomAssertions
      def self.strip_whitespace!(nodes)
        nodes.reject! do |node|
          if node.is_a?(HTML::Text)
            node.content.strip!
            node.content.empty?
          else
            strip_whitespace! node.children
            false
          end
        end
      end
      
      # Test two HTML strings for equivalency (e.g., identical up to reordering of attributes)
      #
      # ==== Examples
      #
      #   # assert that the referenced method generates the appropriate HTML string
      #   assert_dom_equal '<a href="http://www.example.com">Apples</a>', link_to("Apples", "http://www.example.com")
      #
      def assert_dom_equal(expected, actual, message = "")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom   = HTML::Document.new(actual).root
          DomAssertions.strip_whitespace!(expected_dom.children)
          DomAssertions.strip_whitespace!(actual_dom.children)

          full_message = build_message(message, "<?> expected but was\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom == actual_dom }
        end
      end
      
      # The negated form of +assert_dom_equal+.
      #
      # ==== Examples
      #
      #   # assert that the referenced method does not generate the specified HTML string
      #   assert_dom_not_equal '<a href="http://www.example.com">Apples</a>', link_to("Oranges", "http://www.example.com")
      #
      def assert_dom_not_equal(expected, actual, message = "")
        clean_backtrace do
          expected_dom = HTML::Document.new(expected).root
          actual_dom   = HTML::Document.new(actual).root
          DomAssertions.strip_whitespace!(expected_dom.children)
          DomAssertions.strip_whitespace!(actual_dom.children)

          full_message = build_message(message, "<?> expected to be != to\n<?>.", expected_dom.to_s, actual_dom.to_s)
          assert_block(full_message) { expected_dom != actual_dom }
        end
      end
    end
  end
end

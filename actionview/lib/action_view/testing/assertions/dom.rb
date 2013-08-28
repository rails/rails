module ActionView
  module Assertions
    module DomAssertions
      # \Test two HTML strings for equivalency (e.g., equal even when attributes are in another order)
      #
      #   # assert that the referenced method generates the appropriate HTML string
      #   assert_dom_equal '<a href="http://www.example.com">Apples</a>', link_to("Apples", "http://www.example.com")
      def assert_dom_equal(expected, actual, message = nil)
        expected_dom, actual_dom = Loofah.fragment(expected), Loofah.fragment(actual)
        message ||= "Expected: #{expected}\nActual: #{actual}"
        assert compare_doms(expected_dom, actual_dom), message
      end

      # The negated form of +assert_dom_equal+.
      #
      #   # assert that the referenced method does not generate the specified HTML string
      #   assert_dom_not_equal '<a href="http://www.example.com">Apples</a>', link_to("Oranges", "http://www.example.com")
      def assert_dom_not_equal(expected, actual, message = nil)
        expected_dom, actual_dom = Loofah.fragment(expected), Loofah.fragment(actual)
        message ||= "Expected: #{expected}\nActual: #{actual}"
        assert_not compare_doms(expected_dom, actual_dom), message
      end

      protected
        def compare_doms(expected, actual)
          return false unless expected.children.size == actual.children.size

          expected.children.each_with_index do |child, i|
            return false unless equal_children?(child, actual.children[i])
          end
          true
        end

        def equal_children?(child, other_child)
          return false unless child.type == other_child.type

          if child.element?
            child.name == other_child.name &&
                equal_attribute_nodes?(child.attribute_nodes, other_child.attribute_nodes)
          else
            child.to_s == other_child.to_s
          end
        end

        def equal_attribute_nodes?(nodes, other_nodes)
          return false unless nodes.size == other_nodes.size
          nodes = nodes.sort_by(&:name)
          other_nodes = other_nodes.sort_by(&:name)

          nodes.each_with_index do |attr, i|
            return false unless equal_attribute?(attr, other_nodes[i])
          end
          true
        end

        def equal_attribute?(attr, other_attr)
          attr.name == other_attr.name && attr.value == other_attr.value
        end
    end
  end
end

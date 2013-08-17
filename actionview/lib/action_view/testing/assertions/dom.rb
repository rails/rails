module ActionView
  module Assertions
    module DomAssertions
      # \Test two HTML strings for equivalency (e.g., equal even when attributes are in another order)
      #
      #   # assert that the referenced method generates the appropriate HTML string
      #   assert_dom_equal '<a href="http://www.example.com">Apples</a>', link_to("Apples", "http://www.example.com")
      def assert_dom_equal(expected, actual, message = nil)
        assert dom_assertion(expected, actual, message)
      end

      # The negated form of +assert_dom_equal+.
      #
      #   # assert that the referenced method does not generate the specified HTML string
      #   assert_dom_not_equal '<a href="http://www.example.com">Apples</a>', link_to("Oranges", "http://www.example.com")
      def assert_dom_not_equal(expected, actual, message = nil)
        assert_not dom_assertion(expected, actual, message)
      end

      protected
        def dom_assertion(expected_string, actual_string, message = nil)
          expected, actual = Loofah.fragment(expected_string), Loofah.fragment(actual_string)
          message ||= "Expected: #{expected}\nActual: #{actual}"
          return compare_doms(expected, actual), message
        end

        # +compare_doms+ takes two doms loops over all their children and compares each child via +equal_children?+
        def compare_doms(expected, actual)
          return false unless expected.children.size == actual.children.size

          expected.children.each_with_index do |child, i|
            return false unless equal_children?(child, actual.children[i])
          end
          true
        end

        # +equal_children?+ compares children according to their type
        # Determines further comparison via said type
        # i.e. element node children with equal names has their attributes compared using +attributes_are_equal?+
        def equal_children?(child, other_child)
          return false unless child.type == other_child.type

          if child.element?
            child.name == other_child.name &&
                equal_attribute_nodes?(child.attribute_nodes, other_child.attribute_nodes)
          else
            child.to_s == other_child.to_s
          end
        end

        # +equal_attribute_nodes?+ sorts attribute nodes by name and compares
        # each by calling +equal_attribute?+
        def equal_attribute_nodes?(nodes, other_nodes)
          return false unless nodes.size == other_nodes.size
          nodes = nodes.sort_by(&:name)
          other_nodes = other_nodes.sort_by(&:name)

          nodes.each_with_index do |attr, i|
            return false unless equal_attribute?(attr, other_nodes[i])
          end
          true
        end

        # +equal_attribute?+ compares attributes by their name and value
        def equal_attribute?(attr, other_attr)
          attr.name == other_attr.name && attr.value == other_attr.value
        end
    end
  end
end

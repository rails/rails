require 'loofah'

module ActionDispatch
  module Assertions
    module DomAssertions
      # \Test two HTML strings for equivalency (e.g., equal even when attributes are in another order)
      #
      #   # assert that the referenced method generates the appropriate HTML string
      #   assert_dom_equal '<a href="http://www.example.com">Apples</a>', link_to("Apples", "http://www.example.com")
      def assert_dom_equal(expected, actual, message = nil)
        expected_dom, actual_dom = doms_from_strings(expected, actual)
        message ||= "Expected: #{expected_dom}\nActual: #{actual_dom}"
        assert compare_doms(expected_dom, actual_dom), message
      end

      # The negated form of +assert_dom_equal+.
      #
      #   # assert that the referenced method does not generate the specified HTML string
      #   assert_dom_not_equal '<a href="http://www.example.com">Apples</a>', link_to("Oranges", "http://www.example.com")
      def assert_dom_not_equal(expected, actual, message = nil)
        expected_dom, actual_dom = doms_from_strings(expected, actual)
        message ||= "Expected: #{expected_dom}\nActual: #{actual_dom}"
        assert_not compare_doms(expected_dom, actual_dom), message
      end

      protected
        # +doms_from_strings+ creates a Loofah::HTML::DocumentFragment for every string in strings
        def doms_from_strings(*strings)
          strings.map { |str| Loofah.fragment(str) }
        end

        # +compare_doms+ takes two doms loops over all their children and compares each child via +equal_children?+
        def compare_doms(expected, actual)
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

          case child.type
          when Nokogiri::XML::Node::ELEMENT_NODE
            child.name == other_child.name && attributes_are_equal?(child, other_child)
          else
            child.to_s == other_child.to_s
          end
        end

        # +attributes_are_equal?+ sorts elements attributes by name and compares
        # each attribute by calling +equal_attribute?+
        # If those are +true+ the attributes are considered equal
        def attributes_are_equal?(element, other_element)
          first_nodes = element.attribute_nodes.sort_by { |a| a.name }
          other_nodes = other_element.attribute_nodes.sort_by { |a| a.name }

          return false unless first_nodes.size == other_nodes.size
          first_nodes.each_with_index do |attr, i|
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

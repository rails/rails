require 'rexml/document'
require 'html/document'

module ActionController
  module Assertions
    module TagAssertions
      # Asserts that there is a tag/node/element in the body of the response
      # that meets all of the given conditions. The +conditions+ parameter must
      # be a hash of any of the following keys (all are optional):
      #
      # * <tt>:tag</tt>: the node type must match the corresponding value
      # * <tt>:attributes</tt>: a hash. The node's attributes must match the
      #   corresponding values in the hash.
      # * <tt>:parent</tt>: a hash. The node's parent must match the
      #   corresponding hash.
      # * <tt>:child</tt>: a hash. At least one of the node's immediate children
      #   must meet the criteria described by the hash.
      # * <tt>:ancestor</tt>: a hash. At least one of the node's ancestors must
      #   meet the criteria described by the hash.
      # * <tt>:descendant</tt>: a hash. At least one of the node's descendants
      #   must meet the criteria described by the hash.
      # * <tt>:sibling</tt>: a hash. At least one of the node's siblings must
      #   meet the criteria described by the hash.
      # * <tt>:after</tt>: a hash. The node must be after any sibling meeting
      #   the criteria described by the hash, and at least one sibling must match.
      # * <tt>:before</tt>: a hash. The node must be before any sibling meeting
      #   the criteria described by the hash, and at least one sibling must match.
      # * <tt>:children</tt>: a hash, for counting children of a node. Accepts
      #   the keys:
      #   * <tt>:count</tt>: either a number or a range which must equal (or
      #     include) the number of children that match.
      #   * <tt>:less_than</tt>: the number of matching children must be less
      #     than this number.
      #   * <tt>:greater_than</tt>: the number of matching children must be
      #     greater than this number.
      #   * <tt>:only</tt>: another hash consisting of the keys to use
      #     to match on the children, and only matching children will be
      #     counted.
      # * <tt>:content</tt>: the textual content of the node must match the
      #     given value. This will not match HTML tags in the body of a
      #     tag--only text.
      #
      # Conditions are matched using the following algorithm:
      #
      # * if the condition is a string, it must be a substring of the value.
      # * if the condition is a regexp, it must match the value.
      # * if the condition is a number, the value must match number.to_s.
      # * if the condition is +true+, the value must not be +nil+.
      # * if the condition is +false+ or +nil+, the value must be +nil+.
      #
      # Usage:
      #
      #   # assert that there is a "span" tag
      #   assert_tag :tag => "span"
      #
      #   # assert that there is a "span" tag with id="x"
      #   assert_tag :tag => "span", :attributes => { :id => "x" }
      #
      #   # assert that there is a "span" tag using the short-hand
      #   assert_tag :span
      #
      #   # assert that there is a "span" tag with id="x" using the short-hand
      #   assert_tag :span, :attributes => { :id => "x" }
      #
      #   # assert that there is a "span" inside of a "div"
      #   assert_tag :tag => "span", :parent => { :tag => "div" }
      #
      #   # assert that there is a "span" somewhere inside a table
      #   assert_tag :tag => "span", :ancestor => { :tag => "table" }
      #
      #   # assert that there is a "span" with at least one "em" child
      #   assert_tag :tag => "span", :child => { :tag => "em" }
      #
      #   # assert that there is a "span" containing a (possibly nested)
      #   # "strong" tag.
      #   assert_tag :tag => "span", :descendant => { :tag => "strong" }
      #
      #   # assert that there is a "span" containing between 2 and 4 "em" tags
      #   # as immediate children
      #   assert_tag :tag => "span",
      #              :children => { :count => 2..4, :only => { :tag => "em" } } 
      #
      #   # get funky: assert that there is a "div", with an "ul" ancestor
      #   # and an "li" parent (with "class" = "enum"), and containing a 
      #   # "span" descendant that contains text matching /hello world/
      #   assert_tag :tag => "div",
      #              :ancestor => { :tag => "ul" },
      #              :parent => { :tag => "li",
      #                           :attributes => { :class => "enum" } },
      #              :descendant => { :tag => "span",
      #                               :child => /hello world/ }
      #
      # <strong>Please note</strong: #assert_tag and #assert_no_tag only work
      # with well-formed XHTML. They recognize a few tags as implicitly self-closing
      # (like br and hr and such) but will not work correctly with tags
      # that allow optional closing tags (p, li, td). <em>You must explicitly
      # close all of your tags to use these assertions.</em>
      def assert_tag(*opts)
        clean_backtrace do
          opts = opts.size > 1 ? opts.last.merge({ :tag => opts.first.to_s }) : opts.first
          tag = find_tag(opts)
          assert tag, "expected tag, but no tag found matching #{opts.inspect} in:\n#{@response.body.inspect}"
        end
      end
      
      # Identical to #assert_tag, but asserts that a matching tag does _not_
      # exist. (See #assert_tag for a full discussion of the syntax.)
      def assert_no_tag(*opts)
        clean_backtrace do
          opts = opts.size > 1 ? opts.last.merge({ :tag => opts.first.to_s }) : opts.first
          tag = find_tag(opts)
          assert !tag, "expected no tag, but found tag matching #{opts.inspect} in:\n#{@response.body.inspect}"
        end
      end
    end
  end
end

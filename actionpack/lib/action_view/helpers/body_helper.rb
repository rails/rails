require 'action_view/helpers/tag_helper'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'

module ActionView
  module Helpers #:nodoc:
    # The TextHelper module provides a set of methods for filtering, formatting
    # and transforming strings, which can reduce the amount of inline Ruby code in
    # your views. These helper methods extend ActionView making them callable
    # within your template files.
    #
    # XXX: Should the @body_attributes hash have indifferent access?
    module BodyHelper
      # Returns a hash of attributes for the body tag
      # with the default body id and class.
      #
      # You can override the defaults by calling set_body_id and set_body_class
      #
      # You can also pass in an attribute hash directly to provide other attributes:
      #
      #   body_attributes(:style => "padding: 1em;")
      #
      # When using haml, this can be passed directly to the body tag:
      #   %body{body_attributes}
      #
      # When using ERB:
      #   <% content_tag(:body, body_attributes) do - %>
      #      Hello, World!
      #   <% end %>
      def body_attributes(additional_attributes = {})
        attrs = merge_tag_attributes(@body_attributes, additional_attributes)
        attrs[:class] ||= controller_class_names
        attrs
      end

      # This method makes creating a default body tag even easier:
      #   <%= body_tag do -%>
      #     Hello world!
      #   <% end -%>
      def body_tag(additional_attributes = {}, &block)
        content_tag("body", body_attributes(additional_attributes), &block)
      end

      # Returns classes for the current controller and action.
      # For instance, in the PostsController index:
      # => "posts index"
      # And in the Scoped::WizzBangController show action:
      # => "scoped wizz-bang show"
      def controller_class_names
        controller.controller_path.tr("/"," ").dasherize + " " + controller.action_name
      end

      # Uses the TagHelper#merge_tag_attributes! method to add
      # additional attributes to the body tag in the layout.
      def add_body_attributes(attributes)
        @body_attributes ||= {}
        merge_tag_attributes!(@body_attributes, attributes)
      end

    end
  end
end

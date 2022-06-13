# frozen_string_literal: true

require "action_view/helpers/tag_helper"

module ActionView
  # = Action View Debug Helper
  #
  # Provides a method to debug objects.
  module Helpers # :nodoc:
    module DebugHelper
      include TagHelper

      # Returns a YAML representation of +object+ wrapped with <pre> tags.
      # If the object cannot be converted to YAML using +to_yaml+, +inspect+ will be called instead.
      # Useful for inspecting an object at the time of rendering.
      #
      #   @user = User.new({ username: 'testing', password: 'xyz', age: 42})
      #   debug(@user)
      #
      #   # =>
      #   <pre class='debug_dump'>--- !ruby/object:User
      #   attributes:
      #     updated_at:
      #     username: testing
      #     age: 42
      #     password: xyz
      #     created_at:
      #   </pre>
      def debug(object)
        object = ERB::Util.html_escape(object.to_yaml)
        content_tag(:pre, object, class: "debug_dump")
      rescue
        content_tag(:code, object.inspect, class: "debug_dump")
      end
    end
  end
end

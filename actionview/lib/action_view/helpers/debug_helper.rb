# frozen_string_literal: true

require "action_view/helpers/tag_helper"

module ActionView
  # = Action View Debug Helper
  #
  # Provides a set of methods for making it easier to debug Rails objects.
  module Helpers #:nodoc:
    module DebugHelper
      include TagHelper

      # Returns a YAML representation of +object+ wrapped with <pre> and </pre>.
      # If the object cannot be converted to YAML using +to_yaml+, +inspect+ will be called instead.
      # Useful for inspecting an object at the time of rendering.
      #
      #   @user = User.new({ username: 'testing', password: 'xyz', age: 42})
      #   debug(@user)
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
        Marshal.dump(object)
        object = ERB::Util.html_escape(object.to_yaml)
        content_tag(:pre, object, class: "debug_dump")
      rescue # errors from Marshal or YAML
        # Object couldn't be dumped, perhaps because of singleton methods -- this is the fallback
        content_tag(:code, object.inspect, class: "debug_dump")
      end
    end
  end
end

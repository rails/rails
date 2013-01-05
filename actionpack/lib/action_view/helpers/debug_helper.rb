module ActionView
  # = Action View Debug Helper
  #
  # Provides a set of methods for making it easier to debug Rails objects.
  module Helpers
    module DebugHelper

      include TagHelper

      # Returns a YAML representation of +object+ wrapped with <pre> and </pre>.
      # If the object cannot be converted to YAML using +to_yaml+, +inspect+ will be called instead.
      # Useful for inspecting an object at the time of rendering.
      #
      #   @user = User.new({ username: 'testing', password: 'xyz', age: 42}) %>
      #   debug(@user)
      #   # =>
      #   <pre class='debug_dump'>--- !ruby/object:User
      #   attributes:
      #   &nbsp; updated_at:
      #   &nbsp; username: testing
      #
      #   &nbsp; age: 42
      #   &nbsp; password: xyz
      #   &nbsp; created_at:
      #   attributes_cache: {}
      #
      #   new_record: true
      #   </pre>
      def debug(object)
        Marshal::dump(object)
        object = ERB::Util.html_escape(object.to_yaml).gsub("  ", "&nbsp; ").html_safe
        content_tag(:pre, object, :class => "debug_dump")
      rescue Exception  # errors from Marshal or YAML
        # Object couldn't be dumped, perhaps because of singleton methods -- this is the fallback
        content_tag(:code, object.to_yaml, :class => "debug_dump")
      end
    end
  end
end

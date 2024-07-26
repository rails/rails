module ActionView
  module Helpers
    # Provides a set of methods for making it easier to locate problems.
    module DebugHelper
      # Returns a <pre>-tag set with the +object+ dumped by YAML. Very readable way to inspect an object.
      def debug(object)
        "<pre class='debug_dump'>#{h(object.to_yaml).gsub("  ", "&nbsp; ")}</pre>"
      end
    end
  end
end
module ActionView
  module Helpers
    # Provides a set of methods for making it easier to debug Rails objects.
    module DebugHelper
      # Returns a <pre>-tag that has +object+ dumped by YAML. This creates a very
      # readable way to inspect an object.
      #
      # ==== Example
      #  my_hash = {'first' => 1, 'second' => 'two', 'third' => [1,2,3]}
      #  debug(my_hash)
      #
      #  => <pre class='debug_dump'>--- 
      #  first: 1
      #  second: two
      #  third: 
      #  - 1
      #  - 2
      #  - 3
      #  </pre>
      def debug(object)
        begin
          Marshal::dump(object)
          "<pre class='debug_dump'>#{h(object.to_yaml).gsub("  ", "&nbsp; ")}</pre>"
        rescue Exception => e  # errors from Marshal or YAML
          # Object couldn't be dumped, perhaps because of singleton methods -- this is the fallback
          "<code class='debug_dump'>#{h(object.inspect)}</code>"
        end
      end
    end
  end
end
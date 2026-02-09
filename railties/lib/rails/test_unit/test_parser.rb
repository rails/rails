# frozen_string_literal: true

require "prism"

module Rails
  module TestUnit
    # Parse a test file to extract the line ranges of all tests in both
    # method-style (def test_foo) and declarative-style (test "foo" do)
    module TestParser
      @begins_to_ends = {}
      # Helper to translate a method object into the path and line range where
      # the method was defined.
      def self.definition_for(method)
        filepath, start_line = method.source_location
        @begins_to_ends[filepath] ||= ranges(filepath)
        return unless end_line = @begins_to_ends[filepath][start_line]
        [filepath, start_line..end_line]
      end

      private
        def self.ranges(filepath)
          queue = [Prism.parse_file(filepath).value]
          begins_to_ends = {}
          while (node = queue.shift)
            case node.type
            when :def_node
              begins_to_ends[node.location.start_line] = node.location.end_line
            when :call_node
              begins_to_ends[node.location.start_line] = node.location.end_line
            end

            queue.concat(node.compact_child_nodes)
          end
          begins_to_ends
        end
    end
  end
end

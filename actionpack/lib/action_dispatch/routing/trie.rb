require './lib/action_dispatch/routing/trie/node'
require './lib/action_dispatch/routing/simple_scanner'

module ActionDispatch
  module Routing
    class Trie
      attr_reader :root

      def initialize
        @root = Node.new
      end

      def find(key)
        scanner = SimpleScanner.new(key)
        nodes   = [@root]

        while key = scanner.scan
          children = nodes.flat_map { |n| n.children_for key }
          nodes = children unless children.empty?
        end

        nodes
      end

      def add(key, value)
        scanner = PathScanner.new(key)
        node    = @root
        head    = scanner.scan

        if node.match(head[:value]) && scanner.finished?
          node.value << value
        end

        while head = scanner.scan
          node, _node = node.children.detect { |n| n.key == head[:value] }, node

          unless node
            node = Node.new(head[:value], _node)
            _node.add_child node
          end

          if append_node? head[:required], scanner.next_segment_required?
            node.value << value
          end
        end

        node
      end

      private

      def append_node? head_required, next_required
        head_required && !next_required || !head_required
      end
    end
  end
end

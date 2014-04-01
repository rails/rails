require 'active_support/core_ext/string'
require 'thread_safe'

module ActionDispatch
  module Routing
    class Trie
      class Node
        def initialize(key = '', parent = nil)
          @children = []
          @parent   = parent
          @key      = key
          @matcher  = matcher_for(key)
          @value    = []
        end

        attr_reader :children, :key, :parent, :value

        def siblings
          parent ? parent.children : []
        end

        def add_child(node)
          @match_cache = nil
          children << node
        end

        def children_for(key)
          match_cache[key]
        end

        def match(value)
          @matcher === value
        end

        private

        def match_cache
          @match_cache ||= ThreadSafe::Hash.new do |h,k|
            h[k] = children.select { |c| c.match k }
          end
        end

        def matcher_for(key)
          Regexp.compile key.gsub(/[\:\*.]\w+/, '.+')
        end
      end
    end
  end
end

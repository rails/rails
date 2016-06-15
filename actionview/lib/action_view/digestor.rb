require 'concurrent/map'
require 'action_view/dependency_tracker'
require 'monitor'

module ActionView
  class Digestor
    @@digest_mutex = Mutex.new

    class << self
      # Supported options:
      #
      # * <tt>name</tt>   - Template name
      # * <tt>finder</tt>  - An instance of <tt>ActionView::LookupContext</tt>
      # * <tt>dependencies</tt>  - An array of dependent views
      # * <tt>partial</tt>  - Specifies whether the template is a partial
      def digest(name:, finder:, dependencies: [])
        dependencies ||= []
        cache_key = [ name, finder.rendered_format, dependencies ].flatten.compact.join('.')

        # this is a correctly done double-checked locking idiom
        # (Concurrent::Map's lookups have volatile semantics)
        finder.digest_cache[cache_key] || @@digest_mutex.synchronize do
          finder.digest_cache.fetch(cache_key) do # re-check under lock
            partial = name.include?("/_")
            root = tree(name, finder, partial)
            dependencies.each do |injected_dep|
              root.children << Injected.new(injected_dep, nil, nil)
            end
            finder.digest_cache[cache_key] = root.digest(finder)
          end
        end
      end

      def logger
        ActionView::Base.logger || NullLogger
      end

      # Create a dependency tree for template named +name+.
      def tree(name, finder, partial = false, seen = {})
        logical_name = name.gsub(%r|/_|, "/")
        formats = [finder.rendered_format]

        if finder.disable_cache { finder.exists?(logical_name, [], partial, [], formats: formats) }
          template = finder.disable_cache { finder.find(logical_name, [], partial, [], formats: formats) }

          if node = seen[template.identifier] # handle cycles in the tree
            node
          else
            node = seen[template.identifier] = Node.create(name, logical_name, template, partial)

            deps = DependencyTracker.find_dependencies(name, template, finder.view_paths)
            deps.uniq { |n| n.gsub(%r|/_|, "/") }.each do |dep_file|
              node.children << tree(dep_file, finder, true, seen)
            end
            node
          end
        else
          logger.error "  '#{name}' file doesn't exist, so no dependencies"
          logger.error "  Couldn't find template for digesting: #{name}"
          seen[name] ||= Missing.new(name, logical_name, nil)
        end
      end
    end

    class Node
      attr_reader :name, :logical_name, :template, :children

      def self.create(name, logical_name, template, partial)
        klass = partial ? Partial : Node
        klass.new(name, logical_name, template, [])
      end

      def initialize(name, logical_name, template, children = [])
        @name         = name
        @logical_name = logical_name
        @template     = template
        @children     = children
      end

      def digest(finder, stack = [])
        Digest::MD5.hexdigest("#{template.source}-#{dependency_digest(finder, stack)}")
      end

      def dependency_digest(finder, stack)
        children.map do |node|
          if stack.include?(node)
            false
          else
            finder.digest_cache[node.name] ||= begin
                                                 stack.push node
                                                 node.digest(finder, stack).tap { stack.pop }
                                               end
          end
        end.join("-")
      end

      def to_dep_map
        children.any? ? { name => children.map(&:to_dep_map) } : name
      end
    end

    class Partial < Node; end

    class Missing < Node
      def digest(finder, _ = []) '' end
    end

    class Injected < Node
      def digest(finder, _ = []) name end
    end

    class NullLogger
      def self.debug(_); end
      def self.error(_); end
    end
  end
end

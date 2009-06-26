require 'set'

module Rails
  class Application
    module PathParent
      def method_missing(id, *args)
        name = id.to_s

        if name =~ /^(.*)=$/
          @children[$1] = Path.new(args.first, @root)
        elsif path = @children[name]
          path
        else
          super
        end
      end
    end

    class Root
      include PathParent

      attr_reader :path, :load_once, :eager_load
      def initialize(path)
        raise unless path.is_a?(String)

        @children = {}

        # TODO: Move logic from set_root_path initializer
        @path = File.expand_path(path)
        @root = self
        @load_once, @eager_load = Set.new, Set.new
      end
    end

    class Path
      include PathParent

      attr_reader :path
      attr_accessor :glob

      def initialize(path, root)
        @children = {}
        @root     = root
        @paths    = [path].flatten
        @glob     = "**/*.rb"
      end

      def push(path)
        @paths.push path
      end

      alias << push

      def unshift(path)
        @paths.unshift path
      end

      def load_once!
        @load_once = true
        @root.load_once << self
      end

      def load_once?
        @load_once
      end

      def eager_load!
        @eager_load = true
        @root.eager_load << self
      end

      def eager_load?
        @eager_load
      end

      def paths
        @paths.map do |path|
          path.index('/') == 0 ? path : File.join(@root.path, path)
        end
      end

      alias to_a paths
    end
  end
end
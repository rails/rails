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

      attr_reader :path
      def initialize(path)
        raise unless path.is_a?(String)

        @children = {}

        # TODO: Move logic from set_root_path initializer
        @path = File.expand_path(path)
        @root = self
        @load_once, @eager_load, @all_paths = [], [], []
      end

      def load_once
        @load_once.uniq!
        @load_once
      end

      def eager_load
        @eager_load.uniq!
        @eager_load
      end

      def all_paths
        @all_paths.uniq!
        @all_paths
      end

      def load_paths
        all_paths.map { |path| path.paths }.flatten
      end

      def add_to_load_path
        load_paths.reverse_each do |path|
          $LOAD_PATH.unshift(path) if File.directory?(path)
        end
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
        @root.load_once.push *self.paths
      end

      def load_once?
        @load_once
      end

      def eager_load!
        @eager_load = true
        @root.all_paths << self
        @root.eager_load.push *self.paths
      end

      def eager_load?
        @eager_load
      end

      def load_path!
        @load_path = true
        @root.all_paths << self
      end

      def load_path?
        @load_path
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
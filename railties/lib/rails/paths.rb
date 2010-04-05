require 'set'

module Rails
  module Paths
    module PathParent
      attr_reader :children

      def method_missing(id, *args)
        name = id.to_s

        if name =~ /^(.*)=$/ || args.any?
          @children[$1 || name] = Path.new(@root, *args)
        elsif path = @children[name]
          path
        else
          super
        end
      end
    end

    class Root
      include PathParent

      attr_accessor :path

      def initialize(path)
        raise if path.is_a?(Array)

        @children = {}

        @path = path
        @root = self
        @all_paths = []
      end

      def all_paths
        @all_paths.uniq!
        @all_paths
      end

      def load_once
        filter_by(:load_once?)
      end

      def eager_load
        filter_by(:eager_load?)
      end

      def load_paths
        filter_by(:load_path?)
      end

      def push(*)
        raise "Application root can only have one physical path"
      end

      alias unshift push
      alias << push
      alias concat push

    protected

      def filter_by(constraint)
        all_paths.map do |path|
          if path.send(constraint)
            paths  = path.paths
            paths -= path.children.values.map { |p| p.send(constraint) ? [] : p.paths }.flatten
            paths
          else
            []
          end
        end.flatten.uniq.select { |p| File.exists?(p) }
      end
    end

    class Path
      include PathParent, Enumerable

      attr_reader :path
      attr_accessor :glob

      def initialize(root, *paths)
        @options  = paths.last.is_a?(::Hash) ? paths.pop : {}
        @children = {}
        @root     = root
        @paths    = paths.flatten
        @glob     = @options.delete(:glob)

        @load_once  = @options[:load_once]
        @eager_load = @options[:eager_load]
        @load_path  = @options[:load_path] || @eager_load || @load_once

        @root.all_paths << self
      end

      def each
        to_a.each { |p| yield p }
      end

      def push(path)
        @paths.push path
      end

      alias << push

      def unshift(path)
        @paths.unshift path
      end

      def concat(paths)
        @paths.concat paths
      end

      def load_once!
        @load_once = true
        @load_path = true
      end

      def load_once?
        @load_once
      end

      def eager_load!
        @eager_load = true
        @load_path  = true
      end

      def eager_load?
        @eager_load
      end

      def load_path!
        @load_path = true
      end

      def load_path?
        @load_path
      end

      def paths
        raise "You need to set a path root" unless @root.path

        result = @paths.map do |p|
          path = File.expand_path(p, @root.path)
          @glob ? Dir[File.join(path, @glob)] : path
        end

        result.flatten!
        result.uniq!
        result
      end

      alias to_a paths
    end
  end
end
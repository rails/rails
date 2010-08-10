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

      def autoload_once
        filter_by(:autoload_once?)
      end

      def eager_load
        filter_by(:eager_load?)
      end

      def autoload_paths
        filter_by(:autoload?)
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
        all = []
        all_paths.each do |path|
          if path.send(constraint)
            paths  = path.paths
            paths -= path.children.values.map { |p| p.send(constraint) ? [] : p.paths }.flatten
            all.concat(paths)
          end
        end
        all.uniq!
        all.reject! { |p| !File.exists?(p) }
        all
      end
    end

    class Path
      include PathParent, Enumerable

      attr_reader :path
      attr_accessor :glob

      def initialize(root, *paths)
        options   = paths.last.is_a?(::Hash) ? paths.pop : {}
        @children = {}
        @root     = root
        @paths    = paths.flatten
        @glob     = options[:glob]

        autoload_once! if options[:autoload_once]
        eager_load!    if options[:eager_load]
        autoload!      if options[:autoload]
        load_path!     if options[:load_path]

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

      %w(autoload_once eager_load autoload load_path).each do |m|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{m}!
            @#{m} = true
          end

          def skip_#{m}!
            @#{m} = false
          end

          def #{m}?
            @#{m}
          end
        RUBY
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
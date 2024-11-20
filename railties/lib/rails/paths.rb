# frozen_string_literal: true

require "pathname"

module Rails
  module Paths
    # This object is an extended hash that behaves as root of the Rails::Paths system.
    # It allows you to collect information about how you want to structure your application
    # paths through a Hash-like \API. It requires you to give a physical path on initialization.
    #
    #   root = Root.new "/rails"
    #   root.add "app/controllers", eager_load: true
    #
    # The above command creates a new root object and adds "app/controllers" as a path.
    # This means we can get a Rails::Paths::Path object back like below:
    #
    #   path = root["app/controllers"]
    #   path.eager_load?               # => true
    #   path.is_a?(Rails::Paths::Path) # => true
    #
    # The Path[rdoc-ref:Rails::Paths::Path] object is simply an enumerable and
    # allows you to easily add extra paths:
    #
    #   path.is_a?(Enumerable) # => true
    #   path.to_ary.inspect    # => ["app/controllers"]
    #
    #   path << "lib/controllers"
    #   path.to_ary.inspect    # => ["app/controllers", "lib/controllers"]
    #
    # Notice that when you add a path using #add, the
    # Path[rdoc-ref:Rails::Paths::Path] object created already contains the path
    # with the same path value given to #add. In some situations, you may not
    # want this behavior, so you can give <tt>:with</tt> as option.
    #
    #   root.add "config/routes", with: "config/routes.rb"
    #   root["config/routes"].inspect # => ["config/routes.rb"]
    #
    # The #add method accepts the following options as arguments:
    # +eager_load+, +autoload+, +autoload_once+, and +glob+.
    #
    # Finally, the Path[rdoc-ref:Rails::Paths::Path] object also provides a few
    # helpers:
    #
    #   root = Root.new "/rails"
    #   root.add "app/controllers"
    #
    #   root["app/controllers"].expanded # => ["/rails/app/controllers"]
    #   root["app/controllers"].existent # => ["/rails/app/controllers"]
    #
    # Check the Rails::Paths::Path documentation for more information.
    class Root
      attr_accessor :path

      def initialize(path)
        @path = path
        @root = {}
      end

      def []=(path, value)
        glob = self[path] ? self[path].glob : nil
        add(path, with: value, glob: glob)
      end

      def add(path, options = {})
        with = Array(options.fetch(:with, path))
        @root[path] = Path.new(self, path, with, options)
      end

      def [](path)
        @root[path]
      end

      def values
        @root.values
      end

      def keys
        @root.keys
      end

      def values_at(*list)
        @root.values_at(*list)
      end

      def all_paths
        values.tap(&:uniq!)
      end

      def autoload_once
        filter_by(&:autoload_once?)
      end

      def eager_load
        filter_by(&:eager_load?)
      end

      def autoload_paths
        filter_by(&:autoload?)
      end

      def load_paths
        filter_by(&:load_path?)
      end

    private
      def filter_by(&block)
        all_paths.find_all(&block).flat_map { |path|
          paths = path.existent_directories
          paths - path.children.flat_map { |p| yield(p) ? [] : p.existent_directories }
        }.uniq
      end
    end

    class Path
      include Enumerable

      attr_accessor :glob

      def initialize(root, current, paths, options = {})
        @paths   = paths
        @current = current
        @root    = root
        @glob    = options[:glob]
        @exclude = options[:exclude]

        options[:autoload_once] ? autoload_once! : skip_autoload_once!
        options[:eager_load]    ? eager_load!    : skip_eager_load!
        options[:autoload]      ? autoload!      : skip_autoload!
        options[:load_path]     ? load_path!     : skip_load_path!
      end

      def absolute_current # :nodoc:
        File.expand_path(@current, @root.path)
      end

      def children
        keys = @root.keys.find_all { |k|
          k.start_with?(@current) && k != @current
        }
        @root.values_at(*keys.sort)
      end

      def first
        expanded.first
      end

      def last
        expanded.last
      end

      %w(autoload_once eager_load autoload load_path).each do |m|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{m}!        # def eager_load!
            @#{m} = true   #   @eager_load = true
          end              # end
                           #
          def skip_#{m}!   # def skip_eager_load!
            @#{m} = false  #   @eager_load = false
          end              # end
                           #
          def #{m}?        # def eager_load?
            @#{m}          #   @eager_load
          end              # end
        RUBY
      end

      def each(&block)
        @paths.each(&block)
      end

      def <<(path)
        @paths << path
      end
      alias :push :<<

      def concat(paths)
        @paths.concat paths
      end

      def unshift(*paths)
        @paths.unshift(*paths)
      end

      def to_ary
        @paths
      end

      def paths
        raise "You need to set a path root" unless @root.path

        map do |p|
          Pathname.new(@root.path).join(p)
        end
      end

      def extensions # :nodoc:
        $1.split(",") if @glob =~ /\{([\S]+)\}/
      end

      # Expands all paths against the root and return all unique values.
      def expanded
        raise "You need to set a path root" unless @root.path
        result = []

        each do |path|
          path = File.expand_path(path, @root.path)

          if @glob && File.directory?(path)
            result.concat files_in(path)
          else
            result << path
          end
        end

        result.uniq!
        result
      end

      # Returns all expanded paths but only if they exist in the filesystem.
      def existent
        expanded.select do |f|
          does_exist = File.exist?(f)

          if !does_exist && File.symlink?(f)
            raise "File #{f.inspect} is a symlink that does not point to a valid file"
          end
          does_exist
        end
      end

      def existent_directories
        expanded.select { |d| File.directory?(d) }
      end

      alias to_a expanded

      private
        def files_in(path)
          files = Dir.glob(@glob, base: path)
          files -= @exclude if @exclude
          files.map! { |file| File.join(path, file) }
          files.sort
        end
    end
  end
end

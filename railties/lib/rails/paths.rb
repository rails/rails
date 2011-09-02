require 'set'

module Rails
  module Paths
    module PathParent #:nodoc:
      def method_missing(id, *args)
        match = id.to_s.match(/^(.*)=$/)
        full  = [@current, $1 || id].compact.join("/")

        ActiveSupport::Deprecation.warn 'Accessing paths using dot style as in `config.paths.app.controller` is deprecated. Please use ' <<
          '`config.paths["app/controller"]` style instead.'

        if match || args.any?
          @root[full] = Path.new(@root, full, *args)
        elsif path = @root[full]
          path
        else
          super
        end
      end
    end

    # This object is an extended hash that behaves as root of the Rails::Paths system.
    # It allows you to collect information about how you want to structure your application
    # paths by a Hash like API. It requires you to give a physical path on initialization.
    #
    #   root = Root.new
    #   root.add "app/controllers", :eager_load => true
    #
    # The command above creates a new root object and add "app/controllers" as a path.
    # This means we can get a Path object back like below:
    #
    #   path = root["app/controllers"]
    #   path.eager_load?               # => true
    #   path.is_a?(Rails::Paths::Path) # => true
    #
    # The Path object is simply an array and allows you to easily add extra paths:
    #
    #   path.is_a?(Array) # => true
    #   path.inspect      # => ["app/controllers"]
    #
    #   path << "lib/controllers"
    #   path.inspect      # => ["app/controllers", "lib/controllers"]
    #
    # Notice that when you add a path using #add, the path object created already
    # contains the path with the same path value given to #add. In some situations,
    # you may not want this behavior, so you can give :with as option.
    #
    #   root.add "config/routes", :with => "config/routes.rb"
    #   root["config/routes"].inspect # => ["config/routes.rb"]
    #
    # The #add method accepts the following options as arguments:
    # eager_load, autoload, autoload_once and glob.
    #
    # Finally, the Path object also provides a few helpers:
    #
    #   root = Root.new
    #   root.path = "/rails"
    #   root.add "app/controllers"
    #
    #   root["app/controllers"].expanded # => ["/rails/app/controllers"]
    #   root["app/controllers"].existent # => ["/rails/app/controllers"]
    #
    # Check the Path documentation for more information.
    class Root < ::Hash
      include PathParent
      attr_accessor :path

      def initialize(path)
        raise if path.is_a?(Array)
        @current = nil
        @path = path
        @root = self
        super()
      end

      def []=(path, value)
        value = Path.new(self, path, value) unless value.is_a?(Path)
        super(path, value)
      end

      def add(path, options={})
        with = options[:with] || path
        self[path] = Path.new(self, path, with, options)
      end

      def all_paths
        values.tap { |v| v.uniq! }
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

    protected

      def filter_by(constraint)
        all = []
        all_paths.each do |path|
          if path.send(constraint)
            paths  = path.existent
            paths -= path.children.map { |p| p.send(constraint) ? [] : p.existent }.flatten
            all.concat(paths)
          end
        end
        all.uniq!
        all
      end
    end

    class Path < Array
      include PathParent

      attr_reader :path
      attr_accessor :glob

      def initialize(root, current, *paths)
        options = paths.last.is_a?(::Hash) ? paths.pop : {}
        super(paths.flatten)

        @current  = current
        @root     = root
        @glob     = options[:glob]

        options[:autoload_once] ? autoload_once! : skip_autoload_once!
        options[:eager_load]    ? eager_load!    : skip_eager_load!
        options[:autoload]      ? autoload!      : skip_autoload!
        options[:load_path]     ? load_path!     : skip_load_path!
      end

      def children
        keys = @root.keys.select { |k| k.include?(@current) }
        keys.delete(@current)
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

      # Expands all paths against the root and return all unique values.
      def expanded
        raise "You need to set a path root" unless @root.path
        result = []

        each do |p|
          path = File.expand_path(p, @root.path)

          if @glob
            result.concat Dir[File.join(path, @glob)].sort
          else
            result << path
          end
        end

        result.uniq!
        result
      end

      # Returns all expanded paths but only if they exist in the filesystem.
      def existent
        expanded.select { |f| File.exists?(f) }
      end

      def existent_directories
        expanded.select { |d| File.directory?(d) }
      end

      def paths
        ActiveSupport::Deprecation.warn "paths is deprecated. Please call expand instead."
        expanded
      end

      alias to_a expanded
    end
  end
end

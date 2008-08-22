module ActionView #:nodoc:
  class PathSet < Array #:nodoc:
    def self.type_cast(obj)
      if obj.is_a?(String)
        if Base.warn_cache_misses && defined?(Rails) && Rails.initialized?
          Base.logger.debug "[PERFORMANCE] Processing view path during a " +
            "request. This an expense disk operation that should be done at " +
            "boot. You can manually process this view path with " +
            "ActionView::Base.process_view_paths(#{obj.inspect}) and set it " +
            "as your view path"
        end
        Path.new(obj)
      else
        obj
      end
    end

    def initialize(*args)
      super(*args).map! { |obj| self.class.type_cast(obj) }
    end

    def <<(obj)
      super(self.class.type_cast(obj))
    end

    def concat(array)
      super(array.map! { |obj| self.class.type_cast(obj) })
    end

    def insert(index, obj)
      super(index, self.class.type_cast(obj))
    end

    def push(*objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    def unshift(*objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    class Path #:nodoc:
      def self.eager_load_templates!
        @eager_load_templates = true
      end

      def self.eager_load_templates?
        @eager_load_templates || false
      end

      attr_reader :path, :paths
      delegate :to_s, :to_str, :hash, :inspect, :to => :path

      def initialize(path, load = true)
        raise ArgumentError, "path already is a Path class" if path.is_a?(Path)
        @path = path.freeze
        reload! if load
      end

      def ==(path)
        to_str == path.to_str
      end

      def eql?(path)
        to_str == path.to_str
      end

      def [](path)
        raise "Unloaded view path! #{@path}" unless @loaded
        @paths[path]
      end

      def loaded?
        @loaded ? true : false
      end

      def load
        reload! unless loaded?
        self
      end

      # Rebuild load path directory cache
      def reload!
        @paths = {}

        templates_in_path do |template|
          # Eager load memoized methods and freeze cached template
          template.freeze if self.class.eager_load_templates?

          @paths[template.path] = template
          @paths[template.path_without_extension] ||= template
        end

        @paths.freeze
        @loaded = true
      end

      private
        def templates_in_path
          (Dir.glob("#{@path}/**/*/**") | Dir.glob("#{@path}/**")).each do |file|
            unless File.directory?(file)
              yield Template.new(file.split("#{self}/").last, self)
            end
          end
        end
    end

    def load
      each { |path| path.load }
    end

    def reload!
      each { |path| path.reload! }
    end

    def [](template_path)
      each do |path|
        if template = path[template_path]
          return template
        end
      end
      nil
    end
  end
end

module ActionView
  class Template
    class Path
      attr_reader :path, :paths
      delegate :hash, :inspect, :to => :path
      
      def initialize(options)
        @cache = options[:cache]
      end

      def to_s
        if defined?(RAILS_ROOT)
          path.to_s.sub(/^#{Regexp.escape(File.expand_path(RAILS_ROOT))}\//, '')
        else
          path.to_s
        end
      end

      def to_str
        path.to_str
      end

      def ==(path)
        to_str == path.to_str
      end

      def eql?(path)
        to_str == path.to_str
      end

      def find_by_parts(name, extensions = nil, prefix = nil, partial = nil)
        path = prefix ? "#{prefix}/" : ""
    
        name = name.to_s.split("/")
        name[-1] = "_#{name[-1]}" if partial
    
        path << name.join("/")

        template = nil

        Array(extensions).each do |extension|
          extensioned_path = extension ? "#{path}.#{extension}" : path
          break if (template = find_template(extensioned_path))
        end
        template || find_template(path)
      end
  
    private
      def create_template(file)
        Template.new(file.split("#{self}/").last, self)
      end
    end

    class FileSystemPath < Path
      def initialize(path, options = {})
        raise ArgumentError, "path already is a Path class" if path.is_a?(Path)        
        
        super(options)
        @path, @paths = path, {}
        
        # **/*/** is a hax for symlinked directories
        load_templates("#{@path}/{**/*,**}/**") if @cache
      end

    private
    
      def load_template(template)
        template.load!
        template.accessible_paths.each do |path|
          @paths[path] = template
        end
      end
    
      def find_template(path)
        load_templates("#{@path}/#{path}{,.*}") unless @cache
        @paths[path]
      end    
    
      def load_templates(glob)
        Dir[glob].each do |file|
          load_template(create_template(file)) unless File.directory?(file)
        end
      end
      
    end
  end
end
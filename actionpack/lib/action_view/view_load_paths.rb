module ActionView #:nodoc:
  class ViewLoadPaths < Array #:nodoc:
    def self.type_cast(obj)
      obj.is_a?(String) ? LoadPath.new(obj) : obj
    end

    class LoadPath #:nodoc:
      attr_reader :path, :paths
      delegate :to_s, :to_str, :inspect, :to => :path

      def initialize(path)
        @path = path.freeze
        reload!
      end

      def ==(path)
        to_str == path.to_str
      end

      # Rebuild load path directory cache
      def reload!
        @paths = {}

        files.each do |file|
          @paths[file.path] = file
          @paths[file.path_without_extension] ||= file
        end

        @paths.freeze
      end

      def find_template_file_for_partial_path(template_path, template_format)
        @paths["#{template_path}.#{template_format}"] ||
          @paths[template_path] ||
          @paths[template_path.gsub(/\..*$/, '')]
      end

      private
        # Get all the files and directories in the path
        def files_in_path
          Dir.glob("#{@path}/**/*/**") | Dir.glob("#{@path}/**")
        end

        # Create an array of all the files within the path
        def files
          files_in_path.map do |file|
            TemplateFile.from_full_path(@path, file) unless File.directory?(file)
          end.compact
        end
    end

    def initialize(*args)
      super(*args).map! { |obj| self.class.type_cast(obj) }
    end

    def reload!
      each { |path| path.reload! }
    end

    def <<(obj)
      super(self.class.type_cast(obj))
    end

    def push(*objs)
      delete_paths!(objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    def unshift(*objs)
      delete_paths!(objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    def template_exists?(file)
      find_load_path_for_path(file) ? true : false
    end

    def find_load_path_for_path(file)
      find { |path| path.paths[file.to_s] }
    end

    def find_template_file_for_path(template_path)
      template_path_without_extension, template_extension = path_and_extension(template_path.to_s)
      each do |path|
        if f = path.find_template_file_for_partial_path(template_path_without_extension, template_extension)
          return f
        end
      end
      nil
    end

    private
      def delete_paths!(paths)
        paths.each { |p1| delete_if { |p2| p1.to_s == p2.to_s } }
      end

      # Splits the path and extension from the given template_path and returns as an array.
      def path_and_extension(template_path)
        template_path_without_extension = template_path.sub(/\.(\w+)$/, '')
        [template_path_without_extension, $1]
      end
  end
end

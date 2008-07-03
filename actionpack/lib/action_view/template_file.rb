module ActionView #:nodoc:
  # TemplateFile abstracts the pattern of querying a file path for its
  # path with or without its extension. The path is only the partial path
  # from the load path root e.g. "hello/index.html.erb" not
  # "app/views/hello/index.html.erb"
  class TemplateFile
    def self.from_path(path)
      path.is_a?(self) ? path : new(path)
    end

    def self.from_full_path(load_path, full_path)
      file = new(full_path.split(load_path).last)
      file.load_path = load_path
      file.freeze
    end

    attr_accessor :load_path, :base_path, :name, :format, :extension
    delegate :to_s, :inspect, :to => :path

    def initialize(path)
      path = path.dup

      # Clear the forward slash in the beginning
      trim_forward_slash!(path)

      @base_path, @name, @format, @extension = split(path)
    end

    def freeze
      @load_path.freeze
      @base_path.freeze
      @name.freeze
      @format.freeze
      @extension.freeze
      super
    end

    def format_and_extension
      extensions = [format, extension].compact.join(".")
      extensions.blank? ? nil : extensions
    end

    def full_path
      if load_path
        "#{load_path}/#{path}"
      else
        path
      end
    end

    def path
      base_path.to_s + [name, format, extension].compact.join(".")
    end

    def path_without_extension
      base_path.to_s + [name, format].compact.join(".")
    end

    def path_without_format_and_extension
      "#{base_path}#{name}"
    end

    def dup_with_extension(extension)
      file = dup
      file.extension = extension ? extension.to_s : nil
      file
    end

    private
      def trim_forward_slash!(path)
        path.sub!(/^\//, '')
      end

      # Returns file split into an array
      #   [base_path, name, format, extension]
      def split(file)
        if m = file.match(/^(.*\/)?(\w+)\.?(\w+)?\.?(\w+)?\.?(\w+)?$/)
          if m[5] # Mulipart formats
            [m[1], m[2], "#{m[3]}.#{m[4]}", m[5]]
          elsif m[4] # Single format
            [m[1], m[2], m[3], m[4]]
          else # No format
            [m[1], m[2], nil, m[3]]
          end
        end
      end
  end
end

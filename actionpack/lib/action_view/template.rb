require 'action_controller/mime_type'

module ActionView #:nodoc:
  class Template
    extend TemplateHandlers
    extend ActiveSupport::Memoizable
    include Renderable

    attr_accessor :filename, :load_path, :base_path, :name, :format, :extension
    delegate :to_s, :to => :path

    def initialize(template_path, load_paths = [])
      template_path = template_path.dup
      @base_path, @name, @format, @extension = split(template_path)
      @base_path.to_s.gsub!(/\/$/, '') # Push to split method
      @load_path, @filename = find_full_path(template_path, load_paths)

      # Extend with partial super powers
      extend RenderablePartial if @name =~ /^_/
    end

    def format_and_extension
      (extensions = [format, extension].compact.join(".")).blank? ? nil : extensions
    end
    memoize :format_and_extension

    def multipart?
      format && format.include?('.')
    end

    def content_type
      format.gsub('.', '/')
    end

    def mime_type
      Mime::Type.lookup_by_extension(format) if format
    end
    memoize :mime_type

    def path
      [base_path, [name, format, extension].compact.join('.')].compact.join('/')
    end
    memoize :path

    def path_without_extension
      [base_path, [name, format].compact.join('.')].compact.join('/')
    end
    memoize :path_without_extension

    def path_without_format_and_extension
      [base_path, name].compact.join('/')
    end
    memoize :path_without_format_and_extension

    def relative_path
      path = File.expand_path(filename)
      path.sub!(/^#{Regexp.escape(File.expand_path(RAILS_ROOT))}\//, '') if defined?(RAILS_ROOT)
      path
    end
    memoize :relative_path

    def source
      File.read(filename)
    end
    memoize :source

    def method_segment
      relative_path.to_s.gsub(/([^a-zA-Z0-9_])/) { $1.ord }
    end
    memoize :method_segment

    def render_template(view, local_assigns = {})
      render(view, local_assigns)
    rescue Exception => e
      raise e unless filename
      if TemplateError === e
        e.sub_template_of(self)
        raise e
      else
        raise TemplateError.new(self, view.assigns, e)
      end
    end

    private
      def valid_extension?(extension)
        Template.template_handler_extensions.include?(extension)
      end

      def find_full_path(path, load_paths)
        load_paths = Array(load_paths) + [nil]
        load_paths.each do |load_path|
          file = [load_path, path].compact.join('/')
          return load_path, file if File.file?(file)
        end
        raise MissingTemplate.new(load_paths, path)
      end

      # Returns file split into an array
      #   [base_path, name, format, extension]
      def split(file)
        if m = file.match(/^(.*\/)?([^\.]+)\.?(\w+)?\.?(\w+)?\.?(\w+)?$/)
          if m[5] # Multipart formats
            [m[1], m[2], "#{m[3]}.#{m[4]}", m[5]]
          elsif m[4] # Single format
            [m[1], m[2], m[3], m[4]]
          else
            if valid_extension?(m[3]) # No format
              [m[1], m[2], nil, m[3]]
            else # No extension
              [m[1], m[2], m[3], nil]
            end
          end
        end
      end
  end
end

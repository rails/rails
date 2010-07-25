module ActionView #:nodoc:
  class Template
    class Path
      attr_reader :path, :paths
      delegate :hash, :inspect, :to => :path

      def initialize(path)
        raise ArgumentError, "path already is a Path class" if path.is_a?(Path)
        @path = (path.ends_with?(File::SEPARATOR) ? path.to(-2) : path).freeze
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

      # Returns a ActionView::Template object for the given path string. The
      # input path should be relative to the view path directory,
      # +hello/index.html.erb+. This method also has a special exception to
      # match partial file names without a handler extension. So
      # +hello/index.html+ will match the first template it finds with a
      # known template extension, +hello/index.html.erb+. Template extensions
      # should not be confused with format extensions +html+, +js+, +xml+,
      # etc. A format must be supplied to match a formated file. +hello/index+
      # will never match +hello/index.html.erb+.
      def [](path)
      end

      def load!
      end

      def self.new_and_loaded(path)
        new(path).tap do |_path|
          _path.load!
        end
      end

      private
        def relative_path_for_template_file(full_file_path)
          full_file_path.split("#{@path}/").last
        end
    end

    class EagerPath < Path
      def initialize(path)
        super
        @loaded = false
      end

      def load!
        return if @loaded

        @paths = {}
        templates_in_path do |template|
          template.load!
          template.accessible_paths.each do |path|
            @paths[path] = template
          end
        end
        @paths.freeze
        @loaded = true
      end

      def [](path)
        load! unless @loaded
        @paths[path]
      end

      private
        def templates_in_path
          (Dir.glob("#{@path}/**/*/**") | Dir.glob("#{@path}/**")).each do |file|
            yield create_template(file) unless File.directory?(file)
          end
        end

        def create_template(file)
          Template.new(relative_path_for_template_file(file), self)
        end
    end

    extend TemplateHandlers
    extend ActiveSupport::Memoizable
    include Renderable

    # Templates that are exempt from layouts
    @@exempt_from_layout = Set.new([/\.rjs$/])

    # Don't render layouts for templates with the given extensions.
    def self.exempt_from_layout(*extensions)
      regexps = extensions.collect do |extension|
        extension.is_a?(Regexp) ? extension : /\.#{Regexp.escape(extension.to_s)}$/
      end
      @@exempt_from_layout.merge(regexps)
    end

    attr_accessor :template_path, :load_path, :base_path
    attr_accessor :locale, :name, :format, :extension
    attr_writer :filename
    delegate :to_s, :to => :path

    def initialize(template_path, load_path = nil)
      @template_path, @load_path = template_path.dup, load_path
      @base_path, @name, @locale, @format, @extension = split(template_path)
      @base_path.to_s.gsub!(/\/$/, '') # Push to split method

      # Extend with partial super powers
      extend RenderablePartial if @name =~ /^_/
    end

    def accessible_paths
      paths = []

      if valid_extension?(extension)
        paths << path
        paths << path_without_extension
        if multipart?
          formats = format.split(".")
          paths << "#{path_without_format_and_extension}.#{formats.first}"
          paths << "#{path_without_format_and_extension}.#{formats.second}"
        end
      else
        # template without explicit template handler should only be reachable through its exact path
        paths << template_path
      end

      paths
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
      Mime::Type.lookup_by_extension(format) if format && defined?(::Mime)
    end
    memoize :mime_type

    def path
      [base_path, [name, locale, format, extension].compact.join('.')].compact.join('/')
    end
    memoize :path

    def path_without_extension
      [base_path, [name, locale, format].compact.join('.')].compact.join('/')
    end
    memoize :path_without_extension

    def path_without_format_and_extension
      [base_path, [name, locale].compact.join('.')].compact.join('/')
    end
    memoize :path_without_format_and_extension

    def relative_path
      path = File.expand_path(filename)
      path.sub!(/^#{Regexp.escape(File.expand_path(RAILS_ROOT))}\//, '') if defined?(RAILS_ROOT)
      path
    end
    memoize :relative_path

    def exempt_from_layout?
      @@exempt_from_layout.any? { |exempted| path =~ exempted }
    end

    def filename
      # no load_path means this is an "absolute pathed" template
      load_path ? File.join(load_path, template_path) : template_path
    end
    memoize :filename

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

    def load!
      freeze
    end

    private
      def valid_extension?(extension)
        !Template.registered_template_handler(extension).nil?
      end

      def valid_locale?(locale)
        locale && I18n.available_locales.include?(locale.to_sym)
      end

      # Returns file split into an array
      #   [base_path, name, locale, format, extension]
      def split(file)
        if m = file.to_s.match(/^(.*\/)?([^\.]+)\.(.*)$/)
          [m[1], m[2], *parse_extensions(m[3])]
        end
      end

      # returns parsed extensions as an array
      #   [locale, format, extension]
      def parse_extensions(extensions)
        exts = extensions.split(".")

        if extension = valid_extension?(exts.last) && exts.pop || nil
          locale = valid_locale?(exts.first) && exts.shift || nil
          format = exts.join('.') if exts.any? # join('.') is needed for multipart templates
        else # no extension, just format
          format = exts.last
        end

        [locale, format, extension]
      end
  end
end

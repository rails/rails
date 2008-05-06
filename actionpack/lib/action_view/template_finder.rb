module ActionView #:nodoc:
  class TemplateFinder #:nodoc:

    class InvalidViewPath < StandardError #:nodoc:
      attr_reader :unprocessed_path
      def initialize(path)
        @unprocessed_path = path
        super("Unprocessed view path found: #{@unprocessed_path.inspect}.  Set your view paths with #append_view_path, #prepend_view_path, or #view_paths=.")
      end
    end

    cattr_reader :processed_view_paths
    @@processed_view_paths = Hash.new {|hash, key| hash[key] = []}

    cattr_reader :file_extension_cache
    @@file_extension_cache = Hash.new {|hash, key|
      hash[key] = Hash.new {|hash, key| hash[key] = []}
    }

    class << self #:nodoc:

      # This method is not thread safe. Mutex should be used whenever this is accessed from an instance method
      def process_view_paths(*view_paths)
        view_paths.flatten.compact.each do |dir|
          next if @@processed_view_paths.has_key?(dir)
          @@processed_view_paths[dir] = []
          
          # 
          # Dir.glob("#{dir}/**/*/**") reads all the directories in view path and templates inside those directories
          # Dir.glob("#{dir}/**") reads templates residing at top level of view path
          # 
          (Dir.glob("#{dir}/**/*/**") | Dir.glob("#{dir}/**")).each do |file|
            unless File.directory?(file)
              @@processed_view_paths[dir] << file.split(dir).last.sub(/^\//, '')

              # Build extension cache
              extension = file.split(".").last
              if template_handler_extensions.include?(extension)
                key = file.split(dir).last.sub(/^\//, '').sub(/\.(\w+)$/, '')
                @@file_extension_cache[dir][key] << extension
              end
            end
          end
        end
      end

      def update_extension_cache_for(extension)
        @@processed_view_paths.keys.each do |dir|
          Dir.glob("#{dir}/**/*.#{extension}").each do |file|
            key = file.split(dir).last.sub(/^\//, '').sub(/\.(\w+)$/, '')
            @@file_extension_cache[dir][key] << extension
          end
        end
      end

      def template_handler_extensions
        ActionView::Template.template_handler_extensions
      end

      def reload!
        view_paths = @@processed_view_paths.keys

        @@processed_view_paths = Hash.new {|hash, key| hash[key] = []}
        @@file_extension_cache = Hash.new {|hash, key|
          hash[key] = Hash.new {|hash, key| hash[key] = []}
        }

        process_view_paths(view_paths)
      end
    end

    attr_accessor :view_paths

    def initialize(*args)
      @template = args.shift

      @view_paths = args.flatten
      @view_paths = @view_paths.respond_to?(:find) ? @view_paths.dup : [*@view_paths].compact
      check_view_paths(@view_paths)
    end

    def prepend_view_path(path)
      @view_paths.unshift(*path)

      self.class.process_view_paths(path)
    end

    def append_view_path(path)
      @view_paths.push(*path)

      self.class.process_view_paths(path)
    end

    def view_paths=(path)
      @view_paths = path
      self.class.process_view_paths(path)
    end

    def pick_template(template_path, extension)
      file_name = "#{template_path}.#{extension}"
      base_path = find_base_path_for(file_name)
      base_path.blank? ? false : "#{base_path}/#{file_name}"
    end
    alias_method :template_exists?, :pick_template

    def file_exists?(template_path)
      # Clear the forward slash in the beginning if exists
      template_path = template_path.sub(/^\//, '')

      template_file_name, template_file_extension = path_and_extension(template_path)

      if template_file_extension
        template_exists?(template_file_name, template_file_extension)
      else
        template_exists?(template_file_name, pick_template_extension(template_path))
      end
    end

    def find_base_path_for(template_file_name)
      @view_paths.find { |path| @@processed_view_paths[path].include?(template_file_name) }
    end

    # Returns the view path that the full path resides in.
    def extract_base_path_from(full_path)
      @view_paths.find { |p| full_path[0..p.size - 1] == p }
    end

    # Gets the extension for an existing template with the given template_path.
    # Returns the format with the extension if that template exists.
    #
    #   pick_template_extension('users/show')
    #   # => 'html.erb'
    #
    #   pick_template_extension('users/legacy')
    #   # => "rhtml"
    #
    def pick_template_extension(template_path)
      if extension = find_template_extension_from_handler(template_path, @template.template_format) || find_template_extension_from_first_render
        extension
      elsif @template.template_format == :js && extension = find_template_extension_from_handler(template_path, :html)
        @template.template_format = :html
        extension
      end
    end

    def find_template_extension_from_handler(template_path, template_format = @template.template_format)
      formatted_template_path = "#{template_path}.#{template_format}"

      view_paths.each do |path|
        if (extensions = @@file_extension_cache[path][formatted_template_path]).any?
          return "#{template_format}.#{extensions.first}"
        elsif (extensions = @@file_extension_cache[path][template_path]).any?
          return extensions.first.to_s
        end
      end
      nil
    end

    # Splits the path and extension from the given template_path and returns as an array.
    def path_and_extension(template_path)
      template_path_without_extension = template_path.sub(/\.(\w+)$/, '')
      [ template_path_without_extension, $1 ]
    end

    # Determine the template extension from the <tt>@first_render</tt> filename
    def find_template_extension_from_first_render
      File.basename(@template.first_render.to_s)[/^[^.]+\.(.+)$/, 1]
    end

    private
      def check_view_paths(view_paths)
        view_paths.each do |path|
          raise InvalidViewPath.new(path) unless @@processed_view_paths.has_key?(path)
        end
      end
  end
end

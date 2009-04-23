module ActionView
  class Template
  # Abstract super class
    class Path
      def initialize(options)
        @cache  = options[:cache]
        @cached = {}
      end
    
      # Normalizes the arguments and passes it on to find_template
      def find_by_parts(*args)
        find_all_by_parts(*args).first
      end
      
      def find_all_by_parts(name, details = {}, prefix = nil, partial = nil)
        details[:locales] = [I18n.locale]
        name = name.to_s.gsub(handler_matcher, '').split("/")
        find_templates(name.pop, details, [prefix, *name].compact.join("/"), partial)
      end
    
    private
      
      # This is what child classes implement. No defaults are needed
      # because Path guarentees that the arguments are present and
      # normalized.
      def find_templates(name, details, prefix, partial)
        raise NotImplementedError
      end
  
      # TODO: Refactor this to abstract out the file system
      def initialize_template(file)
        t = Template.new(file.split("#{self}/").last, self)
        t.load!
        t
      end
      
      def valid_handlers
        @valid_handlers ||= TemplateHandlers.extensions
      end
      
      def handler_matcher
        @handler_matcher ||= begin
          e = valid_handlers.join('|')
          /\.(?:#{e})$/
        end
      end
      
      def handler_glob
        e = TemplateHandlers.extensions.join(',')
        ".{#{e}}"
      end
      
      def formats_glob
        @formats_glob ||= begin
          formats = Mime::SET.map { |m| m.symbol }
          '{' + formats.map { |l| ".#{l}," }.join + '}'
        end
      end
      
      def cached(key)
        return yield unless @cache
        return @cached[key] if @cached.key?(key)
        @cached[key] = yield
      end
    end
  
    class FileSystemPath < Path
    
      def initialize(path, options = {})
        raise ArgumentError, "path already is a Path class" if path.is_a?(Path)
        super(options)
        @path = path
      end
    
      # TODO: This is the currently needed API. Make this suck less
      # ==== <suck>
      attr_reader :path
    
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
      # ==== </suck>
    
      def find_templates(name, details, prefix, partial)
        if glob = parts_to_glob(name, details, prefix, partial)
          cached(glob) do
            Dir[glob].map do |path|
              initialize_template(path) unless File.directory?(path)
            end.compact
          end
        end
      end
    
    private
  
      def parts_to_glob(name, details, prefix, partial)
        path = ""
        path << "#{prefix}/" unless prefix.empty?
        path << (partial ? "_#{name}" : name)
      
        extensions = ""
        [:locales, :formats].each do |k|
          extensions << if exts = details[k]
            '{' + exts.map {|e| ".#{e},"}.join + '}'
          else
            k == :formats ? formats_glob : ''
          end
        end
        
        "#{@path}/#{path}#{extensions}#{handler_glob}"
      end
    end
  end
end
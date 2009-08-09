require "pathname"
require "action_view/template/template"

module ActionView
  # Abstract superclass
  class Resolver
    def initialize(options)
      @cache  = options[:cache]
      @cached = {}
    end

    # Normalizes the arguments and passes it on to find_template
    def find(*args)
      find_all_by_parts(*args).first
    end
    
    def find_all_by_parts(name, details = {}, prefix = nil, partial = nil)
      details[:locales] = [I18n.locale]
      name = name.to_s.gsub(handler_matcher, '').split("/")
      find_templates(name.pop, details, [prefix, *name].compact.join("/"), partial)
    end
  
  private

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
    def find_templates(name, details, prefix, partial)
      raise NotImplementedError
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
      e = TemplateHandlers.extensions.map{|h| ".#{h},"}.join
      "{#{e}}"
    end
    
    def formats_glob
      @formats_glob ||= begin
        '{' + Mime::SET.symbols.map { |l| ".#{l}," }.join + '}'
      end
    end

    def cached(key)
      return yield unless @cache
      return @cached[key] if @cached.key?(key)
      @cached[key] = yield
    end
  end

  class FileSystemResolver < Resolver

    def initialize(path, options = {})
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super(options)
      @path = Pathname.new(path).expand_path
    end

    # TODO: This is the currently needed API. Make this suck less
    # ==== <suck>
    attr_reader :path

    def to_s
      path.to_s
    end

    def to_str
      path.to_s
    end

    def ==(path)
      to_str == path.to_str
    end

    def eql?(path)
      to_str == path.to_str
    end
    # ==== </suck>

    def find_templates(name, details, prefix, partial, root = "#{@path}/")
      if glob = details_to_glob(name, details, prefix, partial, root)
        cached(glob) do
          Dir[glob].map do |path|
            next if File.directory?(path)
            source = File.read(path)
            identifier = Pathname.new(path).expand_path.to_s

            Template.new(source, identifier, *path_to_details(path))
          end.compact
        end
      end
    end
  
  private

    # :api: plugin
    def details_to_glob(name, details, prefix, partial, root)
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
      
      "#{root}#{path}#{extensions}#{handler_glob}"
    end

    # TODO: fix me
    # :api: plugin
    def path_to_details(path)
      # [:erb, :format => :html, :locale => :en, :partial => true/false]
      if m = path.match(%r'/(_)?[\w-]+(\.[\w-]+)*\.(\w+)$')
        partial = m[1] == '_'
        details = (m[2]||"").split('.').reject { |e| e.empty? }
        handler = Template.handler_class_for_extension(m[3])

        format  = Mime[details.last] && details.pop.to_sym
        locale  = details.last && details.pop.to_sym

        return handler, :format => format, :locale => locale, :partial => partial
      end
    end
  end

  class FileSystemResolverWithFallback < FileSystemResolver

    def find_templates(name, details, prefix, partial)
      templates = super
      return super(name, details, prefix, partial, '') if templates.empty?
      templates
    end

  end
end
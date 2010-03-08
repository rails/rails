require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/array/wrap"
require "action_view/template"

module ActionView
  class Resolver
    def initialize
      @cached = Hash.new { |h1,k1| h1[k1] =
        Hash.new { |h2,k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = {} } } }
    end

    def clear_cache
      @cached.clear
    end

    def find(*args)
      find_all(*args).first
    end

    # Normalizes the arguments and passes it on to find_template.
    def find_all(name, prefix=nil, partial=false, details={}, key=nil)
      name, prefix = normalize_name(name, prefix)

      cached(key, prefix, name, partial) do
        find_templates(name, prefix, partial, details)
      end
    end

  private

    def caching?
      @caching ||= !defined?(Rails.application) || Rails.application.config.cache_classes
    end

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
    def find_templates(name, prefix, partial, details)
      raise NotImplementedError
    end

    # Support legacy foo.erb names even though we now ignore .erb
    # as well as incorrectly putting part of the path in the template
    # name instead of the prefix.
    def normalize_name(name, prefix)
      handlers = Template::Handlers.extensions.join('|')
      name = name.to_s.gsub(/\.(?:#{handlers})$/, '')

      parts = name.split('/')
      return parts.pop, [prefix, *parts].compact.join("/")
    end

    def cached(key, prefix, name, partial)
      return yield unless key && caching?
      scope = @cached[key][prefix][name]
      if scope.key?(partial)
        scope[partial]
      else
        scope[partial] = yield
      end
    end
  end

  class PathResolver < Resolver
    EXTENSION_ORDER = [:locale, :formats, :handlers]

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

  private

    def find_templates(name, prefix, partial, details)
      path = build_path(name, prefix, partial, details)
      query(path, EXTENSION_ORDER.map { |ext| details[ext] })
    end

    def build_path(name, prefix, partial, details)
      path = ""
      path << "#{prefix}/" unless prefix.empty?
      path << (partial ? "_#{name}" : name)
      path
    end

    def query(path, exts)
      query = File.join(@path, path)
      exts.each do |ext|
        query << '{' << ext.map {|e| e && ".#{e}" }.join(',') << '}'
      end

      Dir[query].reject { |p| File.directory?(p) }.map do |p|
        Template.new(File.read(p), File.expand_path(p), *path_to_details(p))
      end
    end

    # # TODO: fix me
    # # :api: plugin
    def path_to_details(path)
      # [:erb, :format => :html, :locale => :en, :partial => true/false]
      if m = path.match(%r'((^|.*/)(_)?[\w-]+)((?:\.[\w-]+)*)\.(\w+)$')
        partial = m[3] == '_'
        details = (m[4]||"").split('.').reject { |e| e.empty? }
        handler = Template.handler_class_for_extension(m[5])

        format  = Mime[details.last] && details.pop.to_sym
        locale  = details.last && details.pop.to_sym

        virtual_path = (m[1].gsub("#{@path}/", "") << details.join("."))

        return handler, :format => format, :locale => locale, :partial => partial,
                        :virtual_path => virtual_path
      end
    end
  end

  class FileSystemResolver < PathResolver
    def initialize(path)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super()
      @path = Pathname.new(path).expand_path
    end

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?
  end
end

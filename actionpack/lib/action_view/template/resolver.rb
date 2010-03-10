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
      details = details.merge(:handlers => default_handlers)

      cached(key, prefix, name, partial) do
        find_templates(name, prefix, partial, details)
      end
    end

  private

    def caching?
      @caching ||= !defined?(Rails.application) || Rails.application.config.cache_classes
    end

    def default_handlers
      Template::Handlers.extensions + [nil]
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
      query(partial, path, EXTENSION_ORDER.map { |ext| details[ext] })
    end

    def build_path(name, prefix, partial, details)
      path = ""
      path << "#{prefix}/" unless prefix.empty?
      path << (partial ? "_#{name}" : name)
      path
    end

    def query(partial, path, exts)
      query = File.join(@path, path)

      exts.each do |ext|
        query << '{' << ext.map {|e| e && ".#{e}" }.join(',') << '}'
      end

      Dir[query].reject { |p| File.directory?(p) }.map do |p|
        handler, format = extract_handler_and_format(p)
        Template.new(File.read(p), File.expand_path(p), handler,
          :partial => partial, :virtual_path => path, :format => format)
      end
    end

    def extract_handler_and_format(path)
      pieces = File.basename(path).split(".")
      pieces.shift

      handler = Template.handler_class_for_extension(pieces.pop)
      format  = pieces.last && Mime[pieces.last] && pieces.pop.to_sym
      [handler, format]
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

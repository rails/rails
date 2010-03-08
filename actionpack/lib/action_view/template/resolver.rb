require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/array/wrap"
require "action_view/template"

module ActionView
  class Resolver

    class_inheritable_accessor(:registered_details)
    self.registered_details = {}

    def self.register_detail(name, options = {})
      registered_details[name] = lambda do |val|
        val = Array.wrap(val || yield)
        val |= [nil] unless options[:allow_nil] == false
        val
      end
    end

    register_detail(:locale)   { [I18n.locale] }
    register_detail(:formats)  { Mime::SET.symbols }
    register_detail(:handlers) { Template::Handlers.extensions }

    def initialize
      @cached = {}
    end

    def find(*args)
      find_all(*args).first
    end

    # Normalizes the arguments and passes it on to find_template.
    def find_all(name, details = {}, prefix = nil, partial = nil)
      details = normalize_details(details)
      name, prefix = normalize_name(name, prefix)

      cached([name, details, prefix, partial]) do
        find_templates(name, details, prefix, partial)
      end
    end

  private

    def caching?
      @caching ||= !defined?(Rails.application) || Rails.application.config.cache_classes
    end

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
    def find_templates(name, details, prefix, partial)
      raise NotImplementedError
    end

    def normalize_details(details)
      details = details.dup
      # TODO: Refactor this concern out of the resolver
      details.delete(:formats) if details[:formats] == [:"*/*"]
      registered_details.each do |k, v|
        details[k] = v.call(details[k])
      end
      details
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

    def cached(key)
      return yield unless caching?
      return @cached[key] if @cached.key?(key)
      @cached[key] = yield
    end
  end

  class PathResolver < Resolver
    EXTENSION_ORDER = [:locale, :formats, :handlers]

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

  private

    def find_templates(name, details, prefix, partial)
      path = build_path(name, details, prefix, partial)
      query(path, EXTENSION_ORDER.map { |ext| details[ext] })
    end

    def build_path(name, details, prefix, partial)
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

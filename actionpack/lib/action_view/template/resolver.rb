require "pathname"
require "active_support/core_ext/class"
require "action_view/template"

module ActionView
  # = Action View Resolver
  class Resolver
    def initialize
      @cached = Hash.new { |h1,k1| h1[k1] =
        Hash.new { |h2,k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = {} } } }
    end

    def clear_cache
      @cached.clear
    end

    # Normalizes the arguments and passes it on to find_template.
    def find_all(name, prefix=nil, partial=false, details={}, key=nil)
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

    def cached(key, prefix, name, partial)
      return yield unless key && caching?
      @cached[key][prefix][name][partial] ||= yield
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
      query(path, EXTENSION_ORDER.map { |ext| details[ext] }, details[:formats])
    end

    def build_path(name, prefix, partial, details)
      path = ""
      path << "#{prefix}/" unless prefix.empty?
      path << (partial ? "_#{name}" : name)
      path
    end

    def query(path, exts, formats)
      query = File.join(@path, path)

      exts.each do |ext|
        query << '{' << ext.map {|e| e && ".#{e}" }.join(',') << ',}'
      end

      query.gsub!(/\{\.html,/, "{.html,.text.html,")
      query.gsub!(/\{\.text,/, "{.text,.text.plain,")

      templates = []
      sanitizer = Hash.new { |h,k| h[k] = Dir["#{File.dirname(k)}/*"] }

      Dir[query].each do |p|
        next if File.directory?(p) || !sanitizer[p].include?(p)

        handler, format = extract_handler_and_format(p, formats)
        contents = File.open(p, "rb") {|io| io.read }

        templates << Template.new(contents, File.expand_path(p), handler,
          :virtual_path => path, :format => format)
      end

      templates
    end

    # Extract handler and formats from path. If a format cannot be a found neither
    # from the path, or the handler, we should return the array of formats given
    # to the resolver.
    def extract_handler_and_format(path, default_formats)
      pieces = File.basename(path).split(".")
      pieces.shift

      handler  = Template.handler_class_for_extension(pieces.pop)

      if pieces.last == "html" && pieces[-2] == "text"
        correct_path = path.gsub(/\.text\.html/, ".html")
        ActiveSupport::Deprecation.warn "The file `#{path}` uses the deprecated format `text.html`. Please rename it to #{correct_path}", caller
      end

      if pieces.last == "plain" && pieces[-2] == "text"
        correct_path = path.gsub(/\.text\.plain/, ".text")
        pieces.pop
        ActiveSupport::Deprecation.warn "The file `#{path}` uses the deprecated format `text.plain`. Please rename it to #{correct_path}", caller
      end

      format   = pieces.last && Mime[pieces.last] && pieces.pop.to_sym
      format ||= handler.default_format if handler.respond_to?(:default_format)
      format ||= default_formats

      [handler, format]
    end
  end

  class FileSystemResolver < PathResolver
    def initialize(path)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super()
      @path = File.expand_path(path)
    end

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?
  end
end

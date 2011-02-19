require "pathname"
require "active_support/core_ext/class"
require "action_view/template"

module ActionView
  # = Action View Resolver
  class Resolver
    cattr_accessor :caching
    self.caching = true

    class << self
      alias :caching? :caching
    end

    def initialize
      @cached = Hash.new { |h1,k1| h1[k1] = Hash.new { |h2,k2|
        h2[k2] = Hash.new { |h3,k3| h3[k3] = Hash.new { |h4,k4| h4[k4] = {} } } } }
    end

    def clear_cache
      @cached.clear
    end

    # Normalizes the arguments and passes it on to find_template.
    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      cached(key, [name, prefix, partial], details, locals) do
        find_templates(name, prefix, partial, details)
      end
    end

  private

    delegate :caching?, :to => "self.class"

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
    def find_templates(name, prefix, partial, details)
      raise NotImplementedError
    end

    # Helpers that builds a path. Useful for building virtual paths.
    def build_path(name, prefix, partial)
      path = ""
      path << "#{prefix}/" unless prefix.empty?
      path << (partial ? "_#{name}" : name)
      path
    end

    # Handles templates caching. If a key is given and caching is on
    # always check the cache before hitting the resolver. Otherwise,
    # it always hits the resolver but check if the resolver is fresher
    # before returning it.
    def cached(key, path_info, details, locals) #:nodoc:
      name, prefix, partial = path_info
      locals = sort_locals(locals)

      if key && caching?
        @cached[key][name][prefix][partial][locals] ||= decorate(yield, path_info, details, locals)
      else
        fresh = decorate(yield, path_info, details, locals)
        return fresh unless key

        scope = @cached[key][name][prefix][partial]
        cache = scope[locals]
        mtime = cache && cache.map(&:updated_at).max

        if !mtime || fresh.empty?  || fresh.any? { |t| t.updated_at > mtime }
          scope[locals] = fresh
        else
          cache
        end
      end
    end

    # Ensures all the resolver information is set in the template.
    def decorate(templates, path_info, details, locals) #:nodoc:
      cached = nil
      templates.each do |t|
        t.locals         = locals
        t.formats        = details[:formats] || [:html] if t.formats.empty?
        t.virtual_path ||= (cached ||= build_path(*path_info))
      end
    end

    if :symbol.respond_to?("<=>")
      def sort_locals(locals) #:nodoc:
        locals.sort.freeze
      end
    else
      def sort_locals(locals) #:nodoc:
        locals = locals.map{ |l| l.to_s }
        locals.sort!
        locals.freeze
      end
    end
  end

  class PathResolver < Resolver
    EXTENSION_ORDER = [:locale, :formats, :handlers]

    private

    def find_templates(name, prefix, partial, details)
      path = build_path(name, prefix, partial)
      query(path, EXTENSION_ORDER.map { |ext| details[ext] }, details[:formats])
    end

    def query(path, exts, formats)
      query = File.join(@path, path)

      query << exts.map { |ext|
        "{#{ext.compact.map { |e| ".#{e}" }.join(',')},}"
      }.join

      query.gsub!(/\{\.html,/, "{.html,.text.html,")
      query.gsub!(/\{\.text,/, "{.text,.text.plain,")

      templates = []
      sanitizer = Hash.new { |h,k| h[k] = Dir["#{File.dirname(k)}/*"] }

      Dir[query].each do |p|
        next if File.directory?(p) || !sanitizer[p].include?(p)

        handler, format = extract_handler_and_format(p, formats)
        contents = File.open(p, "rb") {|io| io.read }

        templates << Template.new(contents, File.expand_path(p), handler,
          :virtual_path => path, :format => format, :updated_at => mtime(p))
      end

      templates
    end

    # Returns the file mtime from the filesystem.
    def mtime(p)
      File.stat(p).mtime
    end

    # Extract handler and formats from path. If a format cannot be a found neither
    # from the path, or the handler, we should return the array of formats given
    # to the resolver.
    def extract_handler_and_format(path, default_formats)
      pieces = File.basename(path).split(".")
      pieces.shift
      handler = Template.handler_for_extension(pieces.pop)
      format  = pieces.last && Mime[pieces.last]
      [handler, format]
    end
  end

  # A resolver that loads files from the filesystem.
  class FileSystemResolver < PathResolver
    def initialize(path)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super()
      @path = File.expand_path(path)
    end

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?
  end

  # The same as FileSystemResolver but does not allow templates to store
  # a virtual path since it is invalid for such resolvers.
  class FallbackFileSystemResolver < FileSystemResolver
    def self.instances
      [new(""), new("/")]
    end

    def decorate(*)
      super.each { |t| t.virtual_path = nil }
    end
  end
end

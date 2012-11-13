require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/class/attribute_accessors"
require "action_view/template"
require "thread"
require "mutex_m"

module ActionView
  # = Action View Resolver
  class Resolver
    # Keeps all information about view path and builds virtual path.
    class Path
      attr_reader :name, :prefix, :partial, :virtual
      alias_method :partial?, :partial

      def self.build(name, prefix, partial)
        virtual = ""
        virtual << "#{prefix}/" unless prefix.empty?
        virtual << (partial ? "_#{name}" : name)
        new name, prefix, partial, virtual
      end

      def initialize(name, prefix, partial, virtual)
        @name    = name
        @prefix  = prefix
        @partial = partial
        @virtual = virtual
      end

      def to_str
        @virtual
      end
      alias :to_s :to_str
    end

    # Threadsafe template cache
    class Cache #:nodoc:
      class CacheEntry
        include Mutex_m

        attr_accessor :templates
      end

      def initialize
        @data = Hash.new { |h1,k1| h1[k1] = Hash.new { |h2,k2|
                  h2[k2] = Hash.new { |h3,k3| h3[k3] = Hash.new { |h4,k4| h4[k4] = {} } } } }
        @mutex = Mutex.new
      end

      # Cache the templates returned by the block
      def cache(key, name, prefix, partial, locals)
        cache_entry = nil

        # first obtain a lock on the main data structure to create the cache entry
        @mutex.synchronize do
          cache_entry = @data[key][name][prefix][partial][locals] ||= CacheEntry.new
        end

        # then to avoid a long lasting global lock, obtain a more granular lock
        # on the CacheEntry itself
        cache_entry.synchronize do
          if Resolver.caching?
            cache_entry.templates ||= yield
          else
            fresh_templates = yield

            if templates_have_changed?(cache_entry.templates, fresh_templates)
              cache_entry.templates = fresh_templates
            else
              cache_entry.templates ||= []
            end
          end
        end
      end

      def clear
        @mutex.synchronize do
          @data.clear
        end
      end

      private

      def templates_have_changed?(cached_templates, fresh_templates)
        # if either the old or new template list is empty, we don't need to (and can't)
        # compare modification times, and instead just check whether the lists are different
        if cached_templates.blank? || fresh_templates.blank?
          return fresh_templates.blank? != cached_templates.blank?
        end

        cached_templates_max_updated_at = cached_templates.map(&:updated_at).max

        # if a template has changed, it will be now be newer than all the cached templates
        fresh_templates.any? { |t| t.updated_at > cached_templates_max_updated_at }
      end
    end

    cattr_accessor :caching
    self.caching = true

    class << self
      alias :caching? :caching
    end

    def initialize
      @cache = Cache.new
    end

    def clear_cache
      @cache.clear
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
      raise NotImplementedError, "Subclasses must implement a find_templates(name, prefix, partial, details) method"
    end

    # Helpers that builds a path. Useful for building virtual paths.
    def build_path(name, prefix, partial)
      Path.build(name, prefix, partial)
    end

    # Handles templates caching. If a key is given and caching is on
    # always check the cache before hitting the resolver. Otherwise,
    # it always hits the resolver but if the key is present, check if the
    # resolver is fresher before returning it.
    def cached(key, path_info, details, locals) #:nodoc:
      name, prefix, partial = path_info
      locals = locals.map { |x| x.to_s }.sort!

      if key
        @cache.cache(key, name, prefix, partial, locals) do
          decorate(yield, path_info, details, locals)
        end
      else
        decorate(yield, path_info, details, locals)
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
  end

  # An abstract class that implements a Resolver with path semantics.
  class PathResolver < Resolver #:nodoc:
    EXTENSIONS = [:locale, :formats, :handlers]
    DEFAULT_PATTERN = ":prefix/:action{.:locale,}{.:formats,}{.:handlers,}"

    def initialize(pattern=nil)
      @pattern = pattern || DEFAULT_PATTERN
      super()
    end

    private

    def find_templates(name, prefix, partial, details)
      path = Path.build(name, prefix, partial)
      query(path, details, details[:formats])
    end

    def query(path, details, formats)
      query = build_query(path, details)

      # deals with case-insensitive file systems.
      sanitizer = Hash.new { |h,dir| h[dir] = Dir["#{dir}/*"] }

      template_paths = Dir[query].reject { |filename|
        File.directory?(filename) ||
          !sanitizer[File.dirname(filename)].include?(filename)
      }

      template_paths.map { |template|
        handler, format = extract_handler_and_format(template, formats)
        contents = File.binread template

        Template.new(contents, File.expand_path(template), handler,
          :virtual_path => path.virtual,
          :format       => format,
          :updated_at   => mtime(template))
      }
    end

    # Helper for building query glob string based on resolver's pattern.
    def build_query(path, details)
      query = @pattern.dup

      prefix = path.prefix.empty? ? "" : "#{escape_entry(path.prefix)}\\1"
      query.gsub!(/\:prefix(\/)?/, prefix)

      partial = escape_entry(path.partial? ? "_#{path.name}" : path.name)
      query.gsub!(/\:action/, partial)

      details.each do |ext, variants|
        query.gsub!(/\:#{ext}/, "{#{variants.compact.uniq.join(',')}}")
      end

      File.expand_path(query, @path)
    end

    def escape_entry(entry)
      entry.gsub(/[*?{}\[\]]/, '\\\\\\&')
    end

    # Returns the file mtime from the filesystem.
    def mtime(p)
      File.mtime(p)
    end

    # Extract handler and formats from path. If a format cannot be a found neither
    # from the path, or the handler, we should return the array of formats given
    # to the resolver.
    def extract_handler_and_format(path, default_formats)
      pieces = File.basename(path).split(".")
      pieces.shift

      extension = pieces.pop
      unless extension
        message = "The file #{path} did not specify a template handler. The default is currently ERB, " \
                  "but will change to RAW in the future."
        ActiveSupport::Deprecation.warn message
      end

      handler = Template.handler_for_extension(extension)
      format  = pieces.last && Template::Types[pieces.last]
      [handler, format]
    end
  end

  # A resolver that loads files from the filesystem. It allows setting your own
  # resolving pattern. Such pattern can be a glob string supported by some variables.
  #
  # ==== Examples
  #
  # Default pattern, loads views the same way as previous versions of rails, eg. when you're
  # looking for `users/new` it will produce query glob: `users/new{.{en},}{.{html,js},}{.{erb,haml},}`
  #
  #   FileSystemResolver.new("/path/to/views", ":prefix/:action{.:locale,}{.:formats,}{.:handlers,}")
  #
  # This one allows you to keep files with different formats in seperated subdirectories,
  # eg. `users/new.html` will be loaded from `users/html/new.erb` or `users/new.html.erb`,
  # `users/new.js` from `users/js/new.erb` or `users/new.js.erb`, etc.
  #
  #   FileSystemResolver.new("/path/to/views", ":prefix/{:formats/,}:action{.:locale,}{.:formats,}{.:handlers,}")
  #
  # If you don't specify a pattern then the default will be used.
  #
  # In order to use any of the customized resolvers above in a Rails application, you just need
  # to configure ActionController::Base.view_paths in an initializer, for example:
  #
  #   ActionController::Base.view_paths = FileSystemResolver.new(
  #     Rails.root.join("app/views"),
  #     ":prefix{/:locale}/:action{.:formats,}{.:handlers,}"
  #   )
  #
  # ==== Pattern format and variables
  #
  # Pattern has to be a valid glob string, and it allows you to use the
  # following variables:
  #
  # * <tt>:prefix</tt> - usually the controller path
  # * <tt>:action</tt> - name of the action
  # * <tt>:locale</tt> - possible locale versions
  # * <tt>:formats</tt> - possible request formats (for example html, json, xml...)
  # * <tt>:handlers</tt> - possible handlers (for example erb, haml, builder...)
  #
  class FileSystemResolver < PathResolver
    def initialize(path, pattern=nil)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super(pattern)
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

  # An Optimized resolver for Rails' most common case.
  class OptimizedFileSystemResolver < FileSystemResolver #:nodoc:
    def build_query(path, details)
      exts = EXTENSIONS.map { |ext| details[ext] }
      query = escape_entry(File.join(@path, path))

      query + exts.map { |ext|
        "{#{ext.compact.uniq.map { |e| ".#{e}," }.join}}"
      }.join
    end
  end

  # The same as FileSystemResolver but does not allow templates to store
  # a virtual path since it is invalid for such resolvers.
  class FallbackFileSystemResolver < FileSystemResolver #:nodoc:
    def self.instances
      [new(""), new("/")]
    end

    def decorate(*)
      super.each { |t| t.virtual_path = nil }
    end
  end
end

# frozen_string_literal: true

require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attribute_accessors"
require "action_view/template"
require "thread"
require "concurrent/map"

module ActionView
  # = Action View Resolver
  class Resolver
    # Keeps all information about view path and builds virtual path.
    class Path
      attr_reader :name, :prefix, :partial, :virtual
      alias_method :partial?, :partial

      def self.build(name, prefix, partial)
        virtual = +""
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
      class SmallCache < Concurrent::Map
        def initialize(options = {})
          super(options.merge(initial_capacity: 2))
        end
      end

      # preallocate all the default blocks for performance/memory consumption reasons
      PARTIAL_BLOCK = lambda { |cache, partial| cache[partial] = SmallCache.new }
      PREFIX_BLOCK  = lambda { |cache, prefix|  cache[prefix]  = SmallCache.new(&PARTIAL_BLOCK) }
      NAME_BLOCK    = lambda { |cache, name|    cache[name]    = SmallCache.new(&PREFIX_BLOCK) }
      KEY_BLOCK     = lambda { |cache, key|     cache[key]     = SmallCache.new(&NAME_BLOCK) }

      # usually a majority of template look ups return nothing, use this canonical preallocated array to save memory
      NO_TEMPLATES = [].freeze

      def initialize
        @data = SmallCache.new(&KEY_BLOCK)
        @query_cache = SmallCache.new
      end

      def inspect
        "#<#{self.class.name}:0x#{(object_id << 1).to_s(16)} keys=#{@data.size} queries=#{@query_cache.size}>"
      end

      # Cache the templates returned by the block
      def cache(key, name, prefix, partial, locals)
        @data[key][name][prefix][partial][locals] ||= canonical_no_templates(yield)
      end

      def cache_query(query) # :nodoc:
        @query_cache[query] ||= canonical_no_templates(yield)
      end

      def clear
        @data.clear
        @query_cache.clear
      end

      # Get the cache size.  Do not call this
      # method. This method is not guaranteed to be here ever.
      def size # :nodoc:
        size = 0
        @data.each_value do |v1|
          v1.each_value do |v2|
            v2.each_value do |v3|
              v3.each_value do |v4|
                size += v4.size
              end
            end
          end
        end

        size + @query_cache.size
      end

      private

        def canonical_no_templates(templates)
          templates.empty? ? NO_TEMPLATES : templates
        end
    end

    cattr_accessor :caching, default: true

    class << self
      alias :caching? :caching
    end

    def initialize
      @cache = Cache.new
    end

    def clear_cache
      @cache.clear
    end

    # Normalizes the arguments and passes it on to find_templates.
    def find_all(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      locals = locals.map(&:to_s).sort!.freeze

      cached(key, [name, prefix, partial], details, locals) do
        _find_all(name, prefix, partial, details, key, locals)
      end
    end

    alias :find_all_anywhere :find_all
    deprecate :find_all_anywhere

    def find_all_with_query(query) # :nodoc:
      @cache.cache_query(query) { find_template_paths(File.join(@path, query)) }
    end

  private

    def _find_all(name, prefix, partial, details, key, locals)
      find_templates(name, prefix, partial, details, locals)
    end

    delegate :caching?, to: :class

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
    def find_templates(name, prefix, partial, details, locals = [])
      raise NotImplementedError, "Subclasses must implement a find_templates(name, prefix, partial, details, locals = []) method"
    end

    # Handles templates caching. If a key is given and caching is on
    # always check the cache before hitting the resolver. Otherwise,
    # it always hits the resolver but if the key is present, check if the
    # resolver is fresher before returning it.
    def cached(key, path_info, details, locals)
      name, prefix, partial = path_info

      if key
        @cache.cache(key, name, prefix, partial, locals) do
          yield
        end
      else
        yield
      end
    end
  end

  # An abstract class that implements a Resolver with path semantics.
  class PathResolver < Resolver #:nodoc:
    EXTENSIONS = { locale: ".", formats: ".", variants: "+", handlers: "." }
    DEFAULT_PATTERN = ":prefix/:action{.:locale,}{.:formats,}{+:variants,}{.:handlers,}"

    def initialize(pattern = nil)
      if pattern
        ActiveSupport::Deprecation.warn "Specifying a custom path for #{self.class} is deprecated. Implement a custom Resolver subclass instead."
        @pattern = pattern
      else
        @pattern = DEFAULT_PATTERN
      end
      @unbound_templates = Concurrent::Map.new
      super()
    end

    def clear_cache
      @unbound_templates.clear
      super()
    end

    private

      def _find_all(name, prefix, partial, details, key, locals)
        path = Path.build(name, prefix, partial)
        query(path, details, details[:formats], locals, cache: !!key)
      end

      def query(path, details, formats, locals, cache:)
        template_paths = find_template_paths_from_details(path, details)
        template_paths = reject_files_external_to_app(template_paths)

        template_paths.map do |template|
          unbound_template =
            if cache
              @unbound_templates.compute_if_absent([template, path.virtual]) do
                build_unbound_template(template, path.virtual)
              end
            else
              build_unbound_template(template, path.virtual)
            end

          unbound_template.bind_locals(locals)
        end
      end

      def build_unbound_template(template, virtual_path)
        handler, format, variant = extract_handler_and_format_and_variant(template)
        source = Template::Sources::File.new(template)

        UnboundTemplate.new(
          source,
          template,
          handler,
          virtual_path: virtual_path,
          format: format,
          variant: variant,
        )
      end

      def reject_files_external_to_app(files)
        files.reject { |filename| !inside_path?(@path, filename) }
      end

      def find_template_paths_from_details(path, details)
        query = build_query(path, details)
        find_template_paths(query)
      end

      def find_template_paths(query)
        Dir[query].uniq.reject do |filename|
          File.directory?(filename) ||
            # deals with case-insensitive file systems.
            !File.fnmatch(query, filename, File::FNM_EXTGLOB)
        end
      end

      def inside_path?(path, filename)
        filename = File.expand_path(filename)
        path = File.join(path, "")
        filename.start_with?(path)
      end

      # Helper for building query glob string based on resolver's pattern.
      def build_query(path, details)
        query = @pattern.dup

        prefix = path.prefix.empty? ? "" : "#{escape_entry(path.prefix)}\\1"
        query.gsub!(/:prefix(\/)?/, prefix)

        partial = escape_entry(path.partial? ? "_#{path.name}" : path.name)
        query.gsub!(/:action/, partial)

        details.each do |ext, candidates|
          if ext == :variants && candidates == :any
            query.gsub!(/:#{ext}/, "*")
          else
            query.gsub!(/:#{ext}/, "{#{candidates.compact.uniq.join(',')}}")
          end
        end

        File.expand_path(query, @path)
      end

      def escape_entry(entry)
        entry.gsub(/[*?{}\[\]]/, '\\\\\\&')
      end

      # Extract handler, formats and variant from path. If a format cannot be found neither
      # from the path, or the handler, we should return the array of formats given
      # to the resolver.
      def extract_handler_and_format_and_variant(path)
        pieces = File.basename(path).split(".")
        pieces.shift

        extension = pieces.pop

        handler = Template.handler_for_extension(extension)
        format, variant = pieces.last.split(EXTENSIONS[:variants], 2) if pieces.last
        format = if format
          Template::Types[format]&.ref
        else
          if handler.respond_to?(:default_format) # default_format can return nil
            handler.default_format
          else
            nil
          end
        end

        # Template::Types[format] and handler.default_format can return nil
        [handler, format, variant]
      end
  end

  # A resolver that loads files from the filesystem.
  class FileSystemResolver < PathResolver
    attr_reader :path

    def initialize(path, pattern = nil)
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
    def initialize(path)
      super(path)
    end

    private

      def find_template_paths_from_details(path, details)
        # Instead of checking for every possible path, as our other globs would
        # do, scan the directory for files with the right prefix.
        query = "#{escape_entry(File.join(@path, path))}*"

        regex = build_regex(path, details)

        Dir[query].uniq.reject do |filename|
          # This regex match does double duty of finding only files which match
          # details (instead of just matching the prefix) and also filtering for
          # case-insensitive file systems.
          !regex.match?(filename) ||
            File.directory?(filename)
        end.sort_by do |filename|
          # Because we scanned the directory, instead of checking for files
          # one-by-one, they will be returned in an arbitrary order.
          # We can use the matches found by the regex and sort by their index in
          # details.
          match = filename.match(regex)
          EXTENSIONS.keys.reverse.map do |ext|
            if ext == :variants && details[ext] == :any
              match[ext].nil? ? 0 : 1
            elsif match[ext].nil?
              # No match should be last
              details[ext].length
            else
              found = match[ext].to_sym
              details[ext].index(found)
            end
          end
        end
      end

      def build_regex(path, details)
        query = escape_entry(File.join(@path, path))
        exts = EXTENSIONS.map do |ext, prefix|
          match =
            if ext == :variants && details[ext] == :any
              ".*?"
            else
              details[ext].compact.uniq.map { |e| Regexp.escape(e) }.join("|")
            end
          prefix = Regexp.escape(prefix)
          "(#{prefix}(?<#{ext}>#{match}))?"
        end.join

        %r{\A#{query}#{exts}\z}
      end
  end

  # The same as FileSystemResolver but does not allow templates to store
  # a virtual path since it is invalid for such resolvers.
  class FallbackFileSystemResolver < FileSystemResolver #:nodoc:
    private_class_method :new

    def self.instances
      [new(""), new("/")]
    end

    def build_unbound_template(template, _)
      super(template, nil)
    end

    def reject_files_external_to_app(files)
      files
    end
  end
end

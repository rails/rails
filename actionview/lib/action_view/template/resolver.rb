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

    TemplateDetails = Struct.new(:path, :locale, :handler, :format, :variant)

    class PathParser # :nodoc:
      def build_path_regex
        handlers = Template::Handlers.extensions.map { |x| Regexp.escape(x) }.join("|")
        formats = Template::Types.symbols.map { |x| Regexp.escape(x) }.join("|")
        locales = "[a-z]{2}(?:-[A-Z]{2})?"
        variants = "[^.]*"

        %r{
          \A
          (?:(?<prefix>.*)/)?
          (?<partial>_)?
          (?<action>.*?)
          (?:\.(?<locale>#{locales}))??
          (?:\.(?<format>#{formats}))??
          (?:\+(?<variant>#{variants}))??
          (?:\.(?<handler>#{handlers}))?
          \z
        }x
      end

      def parse(path)
        @regex ||= build_path_regex
        match = @regex.match(path)
        path = Path.build(match[:action], match[:prefix] || "", !!match[:partial])
        TemplateDetails.new(
          path,
          match[:locale]&.to_sym,
          match[:handler]&.to_sym,
          match[:format]&.to_sym,
          match[:variant]
        )
      end
    end

    # Threadsafe template cache
    class Cache #:nodoc:
      class SmallCache < Concurrent::Map
        def initialize(options = {})
          super(options.merge(initial_capacity: 2))
        end
      end

      # Preallocate all the default blocks for performance/memory consumption reasons
      PARTIAL_BLOCK = lambda { |cache, partial| cache[partial] = SmallCache.new }
      PREFIX_BLOCK  = lambda { |cache, prefix|  cache[prefix]  = SmallCache.new(&PARTIAL_BLOCK) }
      NAME_BLOCK    = lambda { |cache, name|    cache[name]    = SmallCache.new(&PREFIX_BLOCK) }
      KEY_BLOCK     = lambda { |cache, key|     cache[key]     = SmallCache.new(&NAME_BLOCK) }

      # Usually a majority of template look ups return nothing, use this canonical preallocated array to save memory
      NO_TEMPLATES = [].freeze

      def initialize
        @data = SmallCache.new(&KEY_BLOCK)
      end

      def inspect
        "#{to_s[0..-2]} keys=#{@data.size}>"
      end

      # Cache the templates returned by the block
      def cache(key, name, prefix, partial, locals)
        @data[key][name][prefix][partial][locals] ||= canonical_no_templates(yield)
      end

      def clear
        @data.clear
      end

      # Get the cache size. Do not call this
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

        size
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

    def all_template_paths # :nodoc:
      # Not implemented by default
      []
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

  # A resolver that loads files from the filesystem.
  class FileSystemResolver < Resolver
    EXTENSIONS = { locale: ".", formats: ".", variants: "+", handlers: "." }

    attr_reader :path

    def initialize(path)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      @unbound_templates = Concurrent::Map.new
      @path_parser = PathParser.new
      @path = File.expand_path(path)
      super()
    end

    def clear_cache
      @unbound_templates.clear
      @path_parser = PathParser.new
      super
    end

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?

    def all_template_paths # :nodoc:
      paths = template_glob("**/*")
      paths.map do |filename|
        filename.from(@path.size + 1).remove(/\.[^\/]*\z/)
      end.uniq
    end

    private
      def _find_all(name, prefix, partial, details, key, locals)
        path = Path.build(name, prefix, partial)
        query(path, details, details[:formats], locals, cache: !!key)
      end

      def query(path, details, formats, locals, cache:)
        template_paths = find_template_paths_from_details(path, details)

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

      def source_for_template(template)
        Template::Sources::File.new(template)
      end

      def build_unbound_template(template, virtual_path)
        handler, format, variant = extract_handler_and_format_and_variant(template)
        source = source_for_template(template)

        UnboundTemplate.new(
          source,
          template,
          handler,
          virtual_path: virtual_path,
          format: format,
          variant: variant,
        )
      end

      # Safe glob within @path
      def template_glob(glob)
        query = File.join(escape_entry(@path), glob)
        path_with_slash = File.join(@path, "")

        Dir.glob(query).reject do |filename|
          File.directory?(filename)
        end.map do |filename|
          File.expand_path(filename)
        end.select do |filename|
          filename.start_with?(path_with_slash)
        end
      end

      def escape_entry(entry)
        entry.gsub(/[*?{}\[\]]/, '\\\\\\&')
      end

      # Extract handler, formats and variant from path. If a format cannot be found neither
      # from the path, or the handler, we should return the array of formats given
      # to the resolver.
      def extract_handler_and_format_and_variant(path)
        details = @path_parser.parse(path)

        handler = Template.handler_for_extension(details.handler)
        format = details.format || handler.try(:default_format)
        variant = details.variant

        # Template::Types[format] and handler.default_format can return nil
        [handler, format, variant]
      end

      def find_template_paths_from_details(path, details)
        if path.name.include?(".")
          return []
        end

        # Instead of checking for every possible path, as our other globs would
        # do, scan the directory for files with the right prefix.
        candidates = template_glob("#{escape_entry(path.to_s)}*")

        regex = build_regex(path, details)

        candidates.uniq.reject do |filename|
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
          EXTENSIONS.keys.map do |ext|
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
        query = Regexp.escape(File.join(@path, path))
        exts = EXTENSIONS.map do |ext, prefix|
          match =
            if ext == :variants && details[ext] == :any
              ".*?"
            else
              arr = details[ext].compact
              arr.uniq!
              arr.map! { |e| Regexp.escape(e) }
              arr.join("|")
            end
          prefix = Regexp.escape(prefix)
          "(#{prefix}(?<#{ext}>#{match}))?"
        end.join

        %r{\A#{query}#{exts}\z}
      end
  end
end

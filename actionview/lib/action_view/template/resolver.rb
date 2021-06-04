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
    Path = ActionView::TemplatePath
    deprecate_constant :Path

    class PathParser # :nodoc:
      ParsedPath = Struct.new(:path, :details)

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
        path = TemplatePath.build(match[:action], match[:prefix] || "", !!match[:partial])
        details = TemplateDetails.new(
          match[:locale]&.to_sym,
          match[:handler]&.to_sym,
          match[:format]&.to_sym,
          match[:variant]&.to_sym
        )
        ParsedPath.new(path, details)
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
      end.uniq.map do |filename|
        TemplatePath.parse(filename)
      end
    end

    private
      def _find_all(name, prefix, partial, details, key, locals)
        path = TemplatePath.build(name, prefix, partial)
        requested_details = TemplateDetails::Requested.new(**details)
        query(path, requested_details, locals, cache: !!key)
      end

      def query(path, requested_details, locals, cache:)
        cache = cache ? @unbound_templates : Concurrent::Map.new

        unbound_templates =
          cache.compute_if_absent(path.virtual) do
            unbound_templates_from_path(path)
          end

        filter_and_sort_by_details(unbound_templates, requested_details).map do |unbound_template|
          unbound_template.bind_locals(locals)
        end
      end

      def source_for_template(template)
        Template::Sources::File.new(template)
      end

      def build_unbound_template(template)
        parsed = @path_parser.parse(template.from(@path.size + 1))
        details = parsed.details
        source = source_for_template(template)

        UnboundTemplate.new(
          source,
          template,
          details: details,
          virtual_path: parsed.path.virtual,
        )
      end

      def unbound_templates_from_path(path)
        if path.name.include?(".")
          return []
        end

        # Instead of checking for every possible path, as our other globs would
        # do, scan the directory for files with the right prefix.
        paths = template_glob("#{escape_entry(path.to_s)}*")

        paths.map do |path|
          build_unbound_template(path)
        end.select do |template|
          # Select for exact virtual path match, including case sensitivity
          template.virtual_path == path.virtual
        end
      end

      def filter_and_sort_by_details(templates, requested_details)
        filtered_templates = templates.select do |template|
          template.details.matches?(requested_details)
        end

        if filtered_templates.count > 1
          filtered_templates.sort_by! do |template|
            template.details.sort_key_for(requested_details)
          end
        end

        filtered_templates
      end

      # Safe glob within @path
      def template_glob(glob)
        query = File.join(escape_entry(@path), glob)
        path_with_slash = File.join(@path, "")

        Dir.glob(query).filter_map do |filename|
          filename = File.expand_path(filename)
          next if File.directory?(filename)
          next unless filename.start_with?(path_with_slash)

          filename
        end
      end

      def escape_entry(entry)
        entry.gsub(/[*?{}\[\]]/, '\\\\\\&')
      end
  end
end

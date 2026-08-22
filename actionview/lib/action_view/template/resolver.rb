# frozen_string_literal: true

require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attribute_accessors"
require "action_view/template"
require "concurrent/map"

module ActionView
  # = Action View Resolver
  class Resolver
    class PathParser # :nodoc:
      ParsedPath = Struct.new(:path, :details)

      def build_path_regex
        handlers = Regexp.union(Template::Handlers.extensions.map(&:to_s))
        formats = Regexp.union(Template::Types.symbols.map(&:to_s))
        available_locales = I18n.available_locales.map(&:to_s)
        regular_locales = [/[a-z]{2}(?:[-_][A-Z]{2})?/]
        locales = Regexp.union(available_locales + regular_locales)
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

      def path_regex
        @regex ||= build_path_regex
      end

      def parse(path)
        match = path_regex.match(path)
        path = TemplatePath.build(match[:action], match[:prefix] || "", !!match[:partial])
        details = TemplateDetails.new(
          match[:locale]&.to_sym,
          match[:handler]&.to_sym,
          match[:format]&.to_sym,
          match[:variant]&.to_sym
        )
        ParsedPath.new(path, details)
      end

      def freeze
        path_regex
        super
      end
    end

    cattr_accessor :caching, default: true

    class << self
      alias :caching? :caching
    end

    def clear_cache
    end

    def find_all(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      find_templates(name, prefix, partial, details, locals)
    end

    def find(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      find_all(name, prefix, partial, details, key, locals).first
    end

    def built_templates # :nodoc:
      # Used for error pages
      []
    end

    def all_template_paths # :nodoc:
      # Not implemented by default
      []
    end

  private
    delegate :caching?, to: :class

    # Extension point for custom resolvers: implement this method, or
    # override find_all/find directly.
    def find_templates(name, prefix, partial, details, locals = [])
      raise NotImplementedError, "Subclasses must implement a find_templates(name, prefix, partial, details, locals = []) method"
    end
  end

  # A resolver that loads files from the filesystem.
  class FileSystemResolver < Resolver
    attr_reader :path

    def initialize(path)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      @unbound_templates = Concurrent::Map.new
      @directory_entries = Concurrent::Map.new
      @path_parser = PathParser.new
      @path = File.expand_path(path)
      # If a subclass overrides +template_glob+  (as FixtureResolver does),
      # fall back to the glob-based lookup path so those
      # subclasses keep working without any additional changes.
      @template_glob_overridden = method(:template_glob).owner != FileSystemResolver
      super()
    end

    def clear_cache
      @unbound_templates.clear
      @directory_entries.clear
      @path_parser = PathParser.new
      super
    end

    def eager_load_templates(view = nil)
      template_glob("**/*").each do |file|
        unbound = build_unbound_template(file)
        (@unbound_templates[unbound.virtual_path] ||= []) << unbound
        unbound.bind_locals([]).send(:compile!, view) if view
      end
    end

    def freeze
      @path.freeze
      @path_parser.freeze
      @unbound_templates = @unbound_templates.each_pair.to_h unless @unbound_templates.is_a?(::Hash)
      @unbound_templates.each_value do |unbound_templates|
        unbound_templates.each(&:freeze)
        unbound_templates.freeze
      end
      @unbound_templates.freeze
      @directory_entries = @directory_entries.each_pair.to_h unless @directory_entries.is_a?(::Hash)
      @directory_entries.freeze
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

    def built_templates # :nodoc:
      @unbound_templates.values.flatten.flat_map(&:built_templates)
    end

    def find_all(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      requested_details = key || TemplateDetails::Requested.new(**details)
      unbound_templates = unbound_templates_for(name, prefix, partial, !!key)

      filter_and_sort_by_details(unbound_templates, requested_details).map do |unbound_template|
        unbound_template.bind_locals(locals)
      end
    end

    def find(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      requested_details = key || TemplateDetails::Requested.new(**details)
      unbound_templates = unbound_templates_for(name, prefix, partial, !!key)

      unbound_template = find_best_by_details(unbound_templates, requested_details)
      return unless unbound_template
      unbound_template.bind_locals(locals)
    end

    private
      def unbound_templates_for(name, prefix, partial, cached)
        return @unbound_templates[TemplatePath.virtual(name, prefix, partial)] || [].freeze if frozen?
        return unbound_templates_from_path(TemplatePath.build(name, prefix, partial)) unless cached

        @unbound_templates.compute_if_absent(TemplatePath.virtual(name, prefix, partial)) do
          unbound_templates_from_path(TemplatePath.build(name, prefix, partial))
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

        # Instead of running a directory glob for each virtual path, consult a
        # per-directory index of entries keyed by the portion of each filename
        # before its first ".". This turns N template lookups within one
        # directory of N files from O(N^2) directory reads into O(N).
        paths = candidate_template_files(path)

        paths.map do |path|
          build_unbound_template(path)
        end.select do |template|
          # Select for exact virtual path match, including case sensitivity
          template.virtual_path == path.virtual
        end
      end

      # Return the absolute filenames of files that could conceivably resolve to
      # +path+. Subclasses (e.g. FixtureResolver) may override this to serve
      # candidates from a different source.
      def candidate_template_files(path)
        if @template_glob_overridden
          return template_glob("#{escape_entry(path.to_s)}*")
        end

        entries = directory_entries(path.prefix)
        key = path.partial ? "_#{path.name}" : path.name
        entries[key] || EMPTY_ARRAY
      end

      EMPTY_ARRAY = [].freeze
      private_constant :EMPTY_ARRAY

      EMPTY_HASH = {}.freeze
      private_constant :EMPTY_HASH

      def directory_entries(relative_dir)
        @directory_entries.compute_if_absent(relative_dir) do
          build_directory_entries(relative_dir)
        end
      end

      def build_directory_entries(relative_dir)
        dir = relative_dir.empty? ? @path : File.join(@path, relative_dir)
        expanded = File.expand_path(dir)

        # Preserve the traversal guard that template_glob's start_with? check
        # provides: a caller-supplied prefix must not escape @path.
        unless expanded == @path || expanded.start_with?(File.join(@path, ""))
          return EMPTY_HASH
        end

        entries = {}
        Dir.each_child(expanded) do |entry|
          filename = File.join(expanded, entry)
          next if File.directory?(filename)
          # An action name can be followed by "+variant" or ".<locale/format/handler>"
          # (see PathParser). Bucket by the portion of the filename that could
          # match a requested action name.
          split_idx = entry.index(/[.+]/) || entry.length
          (entries[entry[0, split_idx]] ||= []) << filename
        end
        entries.each_value(&:freeze)
        entries.freeze
      rescue SystemCallError
        EMPTY_HASH
      end

      def find_best_by_details(templates, requested_details)
        if templates.size == 1
          template = templates.first
          return template.details.matches?(requested_details) ? template : nil
        end

        best = best_rank = nil
        templates.each do |template|
          rank = template.details.rank_for(requested_details) or next
          if best_rank.nil? || (rank <=> best_rank) < 0
            best = template
            best_rank = rank
          end
        end
        best
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

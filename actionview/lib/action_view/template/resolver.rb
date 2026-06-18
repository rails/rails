# frozen_string_literal: true

require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/access"
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

    cattr_accessor :caching, default: true

    class << self
      alias :caching? :caching
    end

    def clear_cache
    end

    # Returns every matching template. The only multi-template caller is
    # ActionMailer multipart; view rendering resolves via #find.
    def find_all(name, prefix = nil, partial = false, details = {}, cache = false, locals = [])
      _find_all(name, prefix, partial, details, cache, locals)
    end

    # Returns the single best-matching template.
    def find(name, prefix = nil, partial = false, details = {}, cache = false, locals = [])
      _find(name, prefix, partial, details, cache, locals)
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
    def _find_all(name, prefix, partial, details, cache, locals)
      find_templates(name, prefix, partial, details, locals)
    end

    def _find(name, prefix, partial, details, cache, locals)
      find_all(name, prefix, partial, details, cache, locals).first
    end

    delegate :caching?, to: :class

    # This is what child classes implement. No defaults are needed
    # because Resolver guarantees that the arguments are present and
    # normalized.
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

    def built_templates # :nodoc:
      @unbound_templates.values.flatten.flat_map(&:built_templates)
    end

    private
      def _find_all(name, prefix, partial, details, cache, locals)
        unbound_templates = unbound_templates_for(name, prefix, partial, cache)

        filter_and_sort_by_details(unbound_templates, details).map do |unbound_template|
          unbound_template.bind_locals(locals)
        end
      end

      def _find(name, prefix, partial, details, cache, locals)
        unbound_templates = unbound_templates_for(name, prefix, partial, cache)

        find_best_by_details(unbound_templates, details)&.bind_locals(locals)
      end

      def unbound_templates_for(name, prefix, partial, cache)
        store = cache ? @unbound_templates : Concurrent::Map.new
        store.compute_if_absent(TemplatePath.virtual(name, prefix, partial)) do
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

      def filter_and_sort_by_details(templates, details)
        ranked = templates.filter_map do |template|
          rank = details.template_rank(template)
          [rank, template] if rank
        end

        ranked.sort_by!(&:first).map!(&:last)
      end

      def find_best_by_details(templates, details)
        best = best_rank = nil
        templates.each do |template|
          rank = details.template_rank(template) or next
          if best_rank.nil? || (rank <=> best_rank) < 0
            best = template
            best_rank = rank
          end
        end
        best
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

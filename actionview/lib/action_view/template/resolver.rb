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

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

    cattr_accessor :caching, default: true

    class << self
      alias :caching? :caching
    end

    def clear_cache
    end

    # Normalizes the arguments and passes it on to find_templates.
    def find_all(name, prefix = nil, partial = false, details = {}, key = nil, locals = [])
      _find_all(name, prefix, partial, details, key, locals)
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
        requested_details = key || TemplateDetails::Requested.new(**details)
        cache = key ? @unbound_templates : Concurrent::Map.new

        unbound_templates =
          cache.compute_if_absent(TemplatePath.virtual(name, prefix, partial)) do
            path = TemplatePath.build(name, prefix, partial)
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

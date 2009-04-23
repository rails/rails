# encoding: utf-8
# This is so that templates compiled in this file are UTF-8

require 'set'
require "action_view/template/path"

module ActionView
  class Template
    extend TemplateHandlers
    attr_reader :source, :identifier, :handler
    
    def initialize(source, identifier, handler, details)
      @source     = source
      @identifier = identifier
      @handler    = handler
      @details    = details
    end
    
    def render(view, locals, &blk)
      method_name = compile(locals, view)
      view.send(method_name, locals, &blk)
    end
    
    # TODO: Figure out how to abstract this
    def variable_name
      identifier[%r'_?(\w+)(\.\w+)*$', 1].to_sym
    end

    # TODO: Figure out how to abstract this
    def counter_name
      "#{variable_name}_counter".to_sym
    end
    
    # TODO: kill hax
    def partial?
      @details[:partial]
    end
    
    # TODO: Move out of Template
    def mime_type
      Mime::Type.lookup_by_extension(@details[:format]) if @details[:format]
    end
    
  private

    def compile(locals, view)
      method_name = build_method_name(locals)
      
      return method_name if view.respond_to?(method_name)
      
      locals_code = locals.keys.map! { |key| "#{key} = local_assigns[:#{key}];" }.join

      source = <<-end_src
        def #{method_name}(local_assigns)
          old_output_buffer = output_buffer;#{locals_code};#{@handler.call(self)}
        ensure
          self.output_buffer = old_output_buffer
        end
      end_src

      begin
        ActionView::Base::CompiledTemplates.module_eval(source, identifier, 0)
        method_name
      rescue Exception => e # errors from template code
        if logger = (view && view.logger)
          logger.debug "ERROR: compiling #{method_name} RAISED #{e}"
          logger.debug "Function body: #{source}"
          logger.debug "Backtrace: #{e.backtrace.join("\n")}"
        end

        raise ActionView::TemplateError.new(self, {}, e)
      end
    end
  
    def build_method_name(locals)
      # TODO: is locals.keys.hash reliably the same?
      "_render_template_#{@identifier.hash}_#{__id__}_#{locals.keys.hash}".gsub('-', "_")
    end
  end
end

if false
  module ActionView #:nodoc:
    class Template
      extend TemplateHandlers
      extend ActiveSupport::Memoizable
    
      module Loading
        def load!
          @cached = true
          # freeze
        end    
      end
      include Loading    
    
      include Renderable

      # Templates that are exempt from layouts
      @@exempt_from_layout = Set.new([/\.rjs$/])

      # Don't render layouts for templates with the given extensions.
      def self.exempt_from_layout(*extensions)
        regexps = extensions.collect do |extension|
          extension.is_a?(Regexp) ? extension : /\.#{Regexp.escape(extension.to_s)}$/
        end
        @@exempt_from_layout.merge(regexps)
      end

      attr_accessor :template_path, :filename, :load_path, :base_path
      attr_accessor :locale, :name, :format, :extension
      delegate :to_s, :to => :path

      def initialize(template_path, load_paths = [])
        template_path = template_path.dup
        @load_path, @filename = find_full_path(template_path, load_paths)
        @name = template_path.to_s.split("/").last.split(".").first
        # @base_path, @name, @locale, @format, @extension = split(template_path)
        @base_path.to_s.gsub!(/\/$/, '') # Push to split method

        # Extend with partial super powers
        extend RenderablePartial if @name =~ /^_/
      end
    
      def accessible_paths
        paths = []

        if valid_extension?(extension)
          paths << path
          paths << path_without_extension
          if multipart?
            formats = format.split(".")
            paths << "#{path_without_format_and_extension}.#{formats.first}"
            paths << "#{path_without_format_and_extension}.#{formats.second}"
          end
        else
          # template without explicit template handler should only be reachable through its exact path
          paths << template_path
        end

        paths
      end
    
      def relative_path
        path = File.expand_path(filename)
        path.sub!(/^#{Regexp.escape(File.expand_path(RAILS_ROOT))}\//, '') if defined?(RAILS_ROOT)
        path
      end
      memoize :relative_path
    
      def source
        File.read(filename)
      end
      memoize :source
    
      def exempt_from_layout?
        @@exempt_from_layout.any? { |exempted| path =~ exempted }
      end    
    
      def path_without_extension
        [base_path, [name, locale, format].compact.join('.')].compact.join('/')
      end
      memoize :path_without_extension    

      def path_without_format_and_extension
        [base_path, [name, locale].compact.join('.')].compact.join('/')
      end
      memoize :path_without_format_and_extension
    
      def path
        [base_path, [name, locale, format, extension].compact.join('.')].compact.join('/')
      end
      memoize :path
    
      def mime_type
        Mime::Type.lookup_by_extension(format) if format && defined?(::Mime)
      end
      memoize :mime_type      
    
      def multipart?
        format && format.include?('.')
      end    
    
      def content_type
        format && format.gsub('.', '/')
      end    
    
    private
    
      def format_and_extension
        (extensions = [format, extension].compact.join(".")).blank? ? nil : extensions
      end
      memoize :format_and_extension

      def mtime
        File.mtime(filename)
      end
      memoize :mtime

      def method_segment
        relative_path.to_s.gsub(/([^a-zA-Z0-9_])/) { $1.ord }
      end
      memoize :method_segment

      def stale?
        File.mtime(filename) > mtime
      end

      def recompile?
        !@cached
      end

      def valid_extension?(extension)
        !Template.registered_template_handler(extension).nil?
      end

      def valid_locale?(locale)
        I18n.available_locales.include?(locale.to_sym)
      end

      def find_full_path(path, load_paths)
        load_paths = Array(load_paths) + [nil]
        load_paths.each do |load_path|
          file = load_path ? "#{load_path.to_str}/#{path}" : path
          return load_path, file if File.file?(file)
        end
        raise MissingTemplate.new(load_paths, path)
      end
    end
  end
end
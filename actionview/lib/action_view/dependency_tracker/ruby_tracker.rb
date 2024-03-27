# frozen_string_literal: true

module ActionView
  class DependencyTracker # :nodoc:
    class RubyTracker # :nodoc:
      EXPLICIT_DEPENDENCY = /# Template Dependency: (\S+)/

      def self.call(name, template, view_paths = nil)
        new(name, template, view_paths).dependencies
      end

      def dependencies
        WildcardResolver.new(view_paths, render_dependencies + explicit_dependencies).resolve
      end

      def self.supports_view_paths? # :nodoc:
        true
      end

      def initialize(name, template, view_paths = nil, parser_class: RenderParser::Default)
        @name, @template, @view_paths = name, template, view_paths
        @parser_class = parser_class
      end

      private
        attr_reader :template, :name, :view_paths

        def render_dependencies
          return [] unless template.source.include?("render")

          compiled_source = template.handler.call(template, template.source)

          @parser_class.new(@name, compiled_source).render_calls.filter_map do |render_call|
            render_call.gsub(%r|/_|, "/")
          end
        end

        def explicit_dependencies
          template.source.scan(EXPLICIT_DEPENDENCY).flatten.uniq
        end
    end
  end
end

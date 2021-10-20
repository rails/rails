# frozen_string_literal: true

module ActionView
  class DependencyTracker # :nodoc:
    class RipperTracker # :nodoc:
      EXPLICIT_DEPENDENCY = /# Template Dependency: (\S+)/

      def self.call(name, template, view_paths = nil)
        new(name, template, view_paths).dependencies
      end

      def dependencies
        render_dependencies + explicit_dependencies
      end

      def self.supports_view_paths? # :nodoc:
        true
      end

      def initialize(name, template, view_paths = nil)
        @name, @template, @view_paths = name, template, view_paths
      end

      private
        attr_reader :template, :name, :view_paths

        def render_dependencies
          return [] unless template.source.include?("render")

          compiled_source = template.handler.call(template, template.source)

          RenderParser.new(@name, compiled_source).render_calls.filter_map do |render_call|
            next if render_call.end_with?("/_")
            render_call.gsub(%r|/_|, "/")
          end
        end

        def explicit_dependencies
          dependencies = template.source.scan(EXPLICIT_DEPENDENCY).flatten.uniq

          wildcards, explicits = dependencies.partition { |dependency| dependency.end_with?("/*") }

          (explicits + resolve_directories(wildcards)).uniq
        end

        def resolve_directories(wildcard_dependencies)
          return [] unless view_paths
          return [] if wildcard_dependencies.empty?

          # Remove trailing "/*"
          prefixes = wildcard_dependencies.map { |query| query[0..-3] }

          view_paths.flat_map(&:all_template_paths).uniq.filter_map { |path|
            path.to_s if prefixes.include?(path.prefix)
          }.sort
        end
    end
  end
end

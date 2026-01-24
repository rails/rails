# frozen_string_literal: true

module ActionView
  class DependencyTracker # :nodoc:
    class WildcardResolver # :nodoc:
      def initialize(view_paths, dependencies)
        @view_paths = view_paths

        @wildcard_dependencies, @explicit_dependencies =
          dependencies.partition { |dependency| dependency.end_with?("/*") }
      end

      def resolve
        return explicit_dependencies.uniq if !view_paths || wildcard_dependencies.empty?

        (explicit_dependencies + resolved_wildcard_dependencies).uniq
      end

      private
        attr_reader :explicit_dependencies, :wildcard_dependencies, :view_paths

        def resolved_wildcard_dependencies
          # Remove trailing "/*"
          prefixes = wildcard_dependencies.map { |query| query[0..-3] }

          view_paths.flat_map(&:all_template_paths).uniq.filter_map { |path|
            path.to_s if prefixes.include?(path.prefix)
          }.sort
        end
    end
  end
end

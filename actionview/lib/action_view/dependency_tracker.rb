# frozen_string_literal: true

require "concurrent/map"
require "action_view/path_set"

module ActionView
  class DependencyTracker # :nodoc:
    @trackers = Concurrent::Map.new

    def self.find_dependencies(name, template, view_paths = nil)
      tracker = @trackers[template.handler]
      return [] unless tracker

      tracker.call(name, template, view_paths)
    end

    def self.register_tracker(extension, tracker)
      handler = Template.handler_for_extension(extension)
      if tracker.respond_to?(:supports_view_paths?)
        @trackers[handler] = tracker
      else
        @trackers[handler] = lambda { |name, template, _|
          tracker.call(name, template)
        }
      end
    end

    def self.remove_tracker(handler)
      @trackers.delete(handler)
    end

    class ERBTracker # :nodoc:
      EXPLICIT_DEPENDENCY = /# Template Dependency: (\S+)/

      # A valid ruby identifier - suitable for class, method and specially variable names
      IDENTIFIER = /
        [[:alpha:]_] # at least one uppercase letter, lowercase letter or underscore
        [[:word:]]*  # followed by optional letters, numbers or underscores
      /x

      # Any kind of variable name. e.g. @instance, @@class, $global or local.
      # Possibly following a method call chain
      VARIABLE_OR_METHOD_CHAIN = /
        (?:\$|@{1,2})?            # optional global, instance or class variable indicator
        (?:#{IDENTIFIER}\.)*      # followed by an optional chain of zero-argument method calls
        (?<dynamic>#{IDENTIFIER}) # and a final valid identifier, captured as DYNAMIC
      /x

      # A simple string literal. e.g. "School's out!"
      STRING = /
        (?<quote>['"]) # an opening quote
        (?<static>.*?) # with anything inside, captured as STATIC
        \k<quote>      # and a matching closing quote
      /x

      # Part of any hash containing the :partial key
      PARTIAL_HASH_KEY = /
        (?:\bpartial:|:partial\s*=>) # partial key in either old or new style hash syntax
        \s*                          # followed by optional spaces
      /x

      # Part of any hash containing the :layout key
      LAYOUT_HASH_KEY = /
        (?:\blayout:|:layout\s*=>)   # layout key in either old or new style hash syntax
        \s*                          # followed by optional spaces
      /x

      # Matches:
      #   partial: "comments/comment", collection: @all_comments => "comments/comment"
      #   (object: @single_comment, partial: "comments/comment") => "comments/comment"
      #
      #   "comments/comments"
      #   'comments/comments'
      #   ('comments/comments')
      #
      #   (@topic)         => "topics/topic"
      #    topics          => "topics/topic"
      #   (message.topics) => "topics/topic"
      RENDER_ARGUMENTS = /\A
        (?:\s*\(?\s*)                                  # optional opening paren surrounded by spaces
        (?:.*?#{PARTIAL_HASH_KEY}|#{LAYOUT_HASH_KEY})? # optional hash, up to the partial or layout key declaration
        (?:#{STRING}|#{VARIABLE_OR_METHOD_CHAIN})      # finally, the dependency name of interest
      /xm

      LAYOUT_DEPENDENCY = /\A
        (?:\s*\(?\s*)                                  # optional opening paren surrounded by spaces
        (?:.*?#{LAYOUT_HASH_KEY})                      # check if the line has layout key declaration
        (?:#{STRING}|#{VARIABLE_OR_METHOD_CHAIN})      # finally, the dependency name of interest
      /xm

      def self.supports_view_paths? # :nodoc:
        true
      end

      def self.call(name, template, view_paths = nil)
        new(name, template, view_paths).dependencies
      end

      def initialize(name, template, view_paths = nil)
        @name, @template, @view_paths = name, template, view_paths
      end

      def dependencies
        render_dependencies + explicit_dependencies
      end

      attr_reader :name, :template
      private :name, :template

      private
        def source
          template.source
        end

        def directory
          name.split("/")[0..-2].join("/")
        end

        def render_dependencies
          render_dependencies = []
          render_calls = source.split(/\brender\b/).drop(1)

          render_calls.each do |arguments|
            add_dependencies(render_dependencies, arguments, LAYOUT_DEPENDENCY)
            add_dependencies(render_dependencies, arguments, RENDER_ARGUMENTS)
          end

          render_dependencies.uniq
        end

        def add_dependencies(render_dependencies, arguments, pattern)
          arguments.scan(pattern) do
            add_dynamic_dependency(render_dependencies, Regexp.last_match[:dynamic])
            add_static_dependency(render_dependencies, Regexp.last_match[:static])
          end
        end

        def add_dynamic_dependency(dependencies, dependency)
          if dependency
            dependencies << "#{dependency.pluralize}/#{dependency.singularize}"
          end
        end

        def add_static_dependency(dependencies, dependency)
          if dependency
            if dependency.include?("/")
              dependencies << dependency
            else
              dependencies << "#{directory}/#{dependency}"
            end
          end
        end

        def resolve_directories(wildcard_dependencies)
          return [] unless @view_paths

          wildcard_dependencies.flat_map { |query, templates|
            @view_paths.find_all_with_query(query).map do |template|
              "#{File.dirname(query)}/#{File.basename(template).split('.').first}"
            end
          }.sort
        end

        def explicit_dependencies
          dependencies = source.scan(EXPLICIT_DEPENDENCY)
          dependencies.flatten!
          dependencies.uniq!

          wildcards, explicits = dependencies.partition { |dependency| dependency[-1] == "*" }

          out = explicits + resolve_directories(wildcards)
          out.uniq!
          out
        end
    end

    register_tracker :erb, ERBTracker
  end
end

require 'thread_safe'

module ActionView
  class DependencyTracker # :nodoc:
    @trackers = ThreadSafe::Cache.new

    def self.find_dependencies(name, template)
      tracker = @trackers[template.handler]

      if tracker.present?
        tracker.call(name, template)
      else
        []
      end
    end

    def self.register_tracker(extension, tracker)
      handler = Template.handler_for_extension(extension)
      @trackers[handler] = tracker
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

      def self.call(name, template)
        new(name, template).dependencies
      end

      def initialize(name, template)
        @name, @template = name, template
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
            arguments.scan(RENDER_ARGUMENTS) do
              add_dynamic_dependency(render_dependencies, Regexp.last_match[:dynamic])
              add_static_dependency(render_dependencies, Regexp.last_match[:static])
            end
          end

          render_dependencies.uniq
        end

        def add_dynamic_dependency(dependencies, dependency)
          if dependency
            dependencies << "#{dependency.pluralize}/#{dependency.singularize}"
          end
        end

        def add_static_dependency(dependencies, dependency)
          if dependency
            if dependency.include?('/')
              dependencies << dependency
            else
              dependencies << "#{directory}/#{dependency}"
            end
          end
        end

        def explicit_dependencies
          source.scan(EXPLICIT_DEPENDENCY).flatten.uniq
        end
    end

    register_tracker :erb, ERBTracker
  end
end

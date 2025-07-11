# frozen_string_literal: true

module ActionView
  class DependencyTracker # :nodoc:
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
        WildcardResolver.new(@view_paths, render_dependencies + explicit_dependencies).resolve
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
          dependencies = []
          render_calls = source.scan(/<%(?:(?:(?!<%).)*?\brender\b((?:(?!%>).)*?))%>/m).flatten

          render_calls.each do |arguments|
            add_dependencies(dependencies, arguments, LAYOUT_DEPENDENCY)
            add_dependencies(dependencies, arguments, RENDER_ARGUMENTS)
          end

          dependencies
        end

        def add_dependencies(render_dependencies, arguments, pattern)
          arguments.scan(pattern) do
            match = Regexp.last_match
            add_dynamic_dependency(render_dependencies, match[:dynamic])
            add_static_dependency(render_dependencies, match[:static], match[:quote])
          end
        end

        def add_dynamic_dependency(dependencies, dependency)
          if dependency
            dependencies << "#{dependency.pluralize}/#{dependency.singularize}"
          end
        end

        def add_static_dependency(dependencies, dependency, quote_type)
          if quote_type == '"' && dependency.include?('#{')
            scanner = StringScanner.new(dependency)

            wildcard_dependency = +""

            while !scanner.eos?
              if scanner.scan_until(/\#{/)
                unmatched_brackets = 1
                wildcard_dependency << scanner.pre_match

                while unmatched_brackets > 0 && !scanner.eos?
                  found = scanner.scan_until(/[{}]/)
                  return unless found

                  case scanner.matched
                  when "{"
                    unmatched_brackets += 1
                  when "}"
                    unmatched_brackets -= 1
                  end
                end

                wildcard_dependency << "*"
              else
                wildcard_dependency << scanner.rest
                scanner.terminate
              end
            end

            dependencies << wildcard_dependency
          elsif dependency
            if dependency.include?("/")
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
  end
end

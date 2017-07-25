# frozen_string_literal: true

require "shellwords"
require "method_source"
require "rake/file_list"
require "active_support/core_ext/module/attribute_accessors"

module Rails
  module TestUnit
    class Runner
      mattr_reader(:filters) { [] }

      class << self
        def options(opts)
          opts.on("--warnings", "-w", "Run with Ruby warnings enabled") {}
          opts.on("--environment", "-e", "Run tests in the ENV environment") {}
        end

        def parse_options(argv)
          # Perform manual parsing and cleanup since option parser raises on unknown options.
          env_index = argv.index("--environment") || argv.index("-e")
          if env_index
            argv.delete_at(env_index)
            environment = argv.delete_at(env_index).strip
          end
          ENV["RAILS_ENV"] = environment || "test"

          w_index = argv.index("--warnings") || argv.index("-w")
          $VERBOSE = argv.delete_at(w_index) if w_index
        end

        def rake_run(argv = [])
          ARGV.replace Shellwords.split(ENV["TESTOPTS"] || "")

          run(argv)
        end

        def run(argv = [])
          load_tests(argv)

          require "active_support/testing/autorun"
        end

        def load_tests(argv)
          patterns = extract_filters(argv)

          tests = Rake::FileList[patterns.any? ? patterns : "test/**/*_test.rb"]
          tests.to_a.each { |path| require File.expand_path(path) }
        end

        def compose_filter(runnable, filter)
          if filters.any? { |_, lines| lines.any? }
            CompositeFilter.new(runnable, filter, filters)
          else
            filter
          end
        end

        private
          def extract_filters(argv)
            # Extract absolute and relative paths but skip -n /.*/ regexp filters.
            argv.select { |arg| arg =~ %r%^/?\w+/% && !arg.end_with?("/") }.map do |path|
              case
              when path =~ /(:\d+)+$/
                file, *lines = path.split(":")
                filters << [ file, lines ]
                file
              when Dir.exist?(path)
                "#{path}/**/*_test.rb"
              else
                filters << [ path, [] ]
                path
              end
            end
          end
      end
    end

    class CompositeFilter # :nodoc:
      attr_reader :named_filter

      def initialize(runnable, filter, patterns)
        @runnable = runnable
        @named_filter = derive_named_filter(filter)
        @filters = [ @named_filter, *derive_line_filters(patterns) ].compact
      end

      # Minitest uses === to find matching filters.
      def ===(method)
        @filters.any? { |filter| filter === method }
      end

      private
        def derive_named_filter(filter)
          if filter.respond_to?(:named_filter)
            filter.named_filter
          elsif filter =~ %r%/(.*)/% # Regexp filtering copied from Minitest.
            Regexp.new $1
          elsif filter.is_a?(String)
            filter
          end
        end

        def derive_line_filters(patterns)
          patterns.flat_map do |file, lines|
            if lines.empty?
              Filter.new(@runnable, file, nil) if file
            else
              lines.map { |line| Filter.new(@runnable, file, line) }
            end
          end
        end
    end

    class Filter # :nodoc:
      def initialize(runnable, file, line)
        @runnable, @file = runnable, File.expand_path(file)
        @line = line.to_i if line
      end

      def ===(method)
        return unless @runnable.method_defined?(method)

        if @line
          test_file, test_range = definition_for(@runnable.instance_method(method))
          test_file == @file && test_range.include?(@line)
        else
          @runnable.instance_method(method).source_location.first == @file
        end
      end

      private
        def definition_for(method)
          file, start_line = method.source_location
          end_line = method.source.count("\n") + start_line - 1

          return file, start_line..end_line
        end
    end
  end
end

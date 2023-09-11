# frozen_string_literal: true

require "shellwords"
require "rake/file_list"
require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/range"
require "rails/test_unit/test_parser"

module Rails
  module TestUnit
    class Runner
      TEST_FOLDERS = [:models, :helpers, :channels, :controllers, :mailers, :integration, :jobs, :mailboxes]
      PATH_ARGUMENT_PATTERN = %r"^(?!/.+/$)[.\w]*[/\\]"
      mattr_reader :filters, default: []

      class << self
        def attach_before_load_options(opts)
          opts.on("--warnings", "-w", "Run with Ruby warnings enabled") { }
          opts.on("-e", "--environment ENV", "Run tests in the ENV environment") { }
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

        def run_from_rake(test_command, argv = [])
          # Ensure the tests run during the Rake Task action, not when the process exits
          success = system("rails", test_command, *argv, *Shellwords.split(ENV["TESTOPTS"] || ""))
          success || exit(false)
        end

        def run(argv = [])
          load_tests(argv)

          require "active_support/testing/autorun"
        end

        def load_tests(argv)
          patterns = extract_filters(argv)
          tests = list_tests(patterns)
          tests.to_a.each { |path| require File.expand_path(path) }
        end

        def compose_filter(runnable, filter)
          filter = normalize_declarative_test_filter(filter)

          if filters.any? { |_, lines| lines.any? }
            CompositeFilter.new(runnable, filter, filters)
          else
            filter
          end
        end

        private
          def extract_filters(argv)
            # Extract absolute and relative paths but skip -n /.*/ regexp filters.
            argv.filter_map do |path|
              next unless path_argument?(path)

              path = path.tr("\\", "/")
              case
              when /(:\d+(-\d+)?)+$/.match?(path)
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

          def default_test_glob
            ENV["DEFAULT_TEST"] || "test/**/*_test.rb"
          end

          def default_test_exclude_glob
            ENV["DEFAULT_TEST_EXCLUDE"] || "test/{system,dummy}/**/*_test.rb"
          end

          def regexp_filter?(arg)
            arg.start_with?("/") && arg.end_with?("/")
          end

          def path_argument?(arg)
            PATH_ARGUMENT_PATTERN.match?(arg)
          end

          def list_tests(patterns)
            tests = Rake::FileList[patterns.any? ? patterns : default_test_glob]
            tests.exclude(default_test_exclude_glob) if patterns.empty?
            tests
          end

          def normalize_declarative_test_filter(filter)
            if filter.is_a?(String)
              if regexp_filter?(filter)
                # Minitest::Spec::DSL#it does not replace whitespace in method
                # names, so match unmodified method names as well.
                filter = filter.gsub(/\s+/, "_").delete_suffix("/") + "|" + filter.delete_prefix("/")
              elsif !filter.start_with?("test_")
                filter = "test_#{filter.gsub(/\s+/, "_")}"
              end
            end
            filter
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

      # minitest uses === to find matching filters.
      def ===(method)
        @filters.any? { |filter| filter === method }
      end

      private
        def derive_named_filter(filter)
          if filter.respond_to?(:named_filter)
            filter.named_filter
          elsif filter =~ %r%/(.*)/% # Regexp filtering copied from minitest.
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
      def initialize(runnable, file, line_or_range)
        @runnable, @file = runnable, File.expand_path(file)
        if line_or_range
          first, last = line_or_range.split("-").map(&:to_i)
          last ||= first
          @line_range = Range.new(first, last)
        end
      end

      def ===(method)
        return unless @runnable.method_defined?(method)

        if @line_range
          test_file, test_range = definition_for(@runnable.instance_method(method))
          test_file == @file && @line_range.overlaps?(test_range)
        else
          @runnable.instance_method(method).source_location.first == @file
        end
      end

      private
        def definition_for(method)
          TestParser.definition_for(method)
        end
    end
  end
end

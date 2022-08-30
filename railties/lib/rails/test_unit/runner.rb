# frozen_string_literal: true

require "shellwords"
require "rake/file_list"
require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "ripper"

module Rails
  module TestUnit
    class Runner
      TEST_FOLDERS = [:models, :helpers, :channels, :controllers, :mailers, :integration, :jobs, :mailboxes]
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

        def rake_run(argv = [])
          # Ensure the tests run during the Rake Task action, not when the process exits
          success = system("rails", "test", *argv, *Shellwords.split(ENV["TESTOPTS"] || ""))
          success || exit(false)
        end

        def run(argv = [])
          load_tests(argv)

          require "active_support/testing/autorun"
        end

        def load_tests(argv)
          tests = list_tests(argv)
          tests.to_a.each { |path| require File.expand_path(path) }
        end

        def compose_filter(runnable, filter)
          filter = escape_declarative_test_filter(filter)

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
              next unless path_argument?(path) && !regexp_filter?(path)

              path = path.tr("\\", "/")
              case
              when /(:\d+)+$/.match?(path)
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
            %r"^\.*[/\\]?\w+[/\\]".match?(arg)
          end

          def list_tests(argv)
            patterns = extract_filters(argv)

            tests = Rake::FileList[patterns.any? ? patterns : default_test_glob]
            tests.exclude(default_test_exclude_glob) if patterns.empty?
            tests
          end

          def escape_declarative_test_filter(filter)
            if filter.is_a?(String) && !filter.start_with?("test_")
              filter = "test_#{filter}" unless regexp_filter?(filter)
              filter = filter.gsub(/\s+/, "_")
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
          end_line = MethodEndFinder.call(source: File.read(file), target: method.name)

          return file, start_line..end_line
        end

        # Finds the line number where the definition of method named +target+ ends.
        module MethodEndFinder # :nodoc:
          def self.call(source:, target:)
            catch(:line_number_is) do
              DefParser.new(source: source, target: target).parse
              return nil
            end
          end

          class DefParser < Ripper # :nodoc:
            def initialize(source:, target:)
              @target = String(target)
              super(source)
            end

            def on_def(method_name, *)
              if method_name == @target
                throw(:line_number_is, lineno)
              end
            end
          end
        end
    end
  end
end

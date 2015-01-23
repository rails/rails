require "ostruct"
require "optparse"
require "rake/file_list"
require "method_source"

module Rails
  class TestRunner
    class Options
      def self.parse(args)
        options = { backtrace: false, name: nil }

        opt_parser = ::OptionParser.new do |opts|
          opts.banner = "Usage: bin/rails test [options]"

          opts.separator ""
          opts.separator "Filter options:"

          opts.on("-n", "--name [NAME]",
                  "Only run tests matching NAME") do |name|
            options[:name] = name
          end

          opts.separator ""
          opts.separator "Output options:"

          opts.on("-b", "--backtrace",
                  "show the complte backtrace") do
            options[:backtrace] = true
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end
        end

        opt_parser.order!(args)
        options[:pattern] = ARGV.shift
        options
      end
    end

    def initialize(options = {})
      @options = options
    end

    def run
      enable_backtrace if @options[:backtrace]
      filter_tests_by_name if @options[:name]

      run_tests
    end

    def find_method
      return if @line.blank?
      method = test_methods.find do |test_method, start_line, end_line|
        (start_line..end_line).include?(@line.to_i)
      end
      method.first if method
    end

    private
    def run_tests
      test_files.to_a.each do |file|
        require File.expand_path file
      end
    end

    NAMED_PATTERNS = {
      "models" => "test/models/**/*_test.rb"
    }
    def test_files
      if @options[:pattern]
        pattern = NAMED_PATTERNS[@options[:pattern]]
        unless pattern
          filename, @line = @options[:pattern].split(':')
          return [filename] if filename
        end
      else
        pattern = "test/**/*_test.rb"
      end
      Rake::FileList[pattern]
    end

    def enable_backtrace
      ENV["BACKTRACE"] = "1"
    end

    def filter_tests_by_name
      ARGV.push("-n", @options[:name])
    end

    def test_methods
      methods_map = []
      suites = Minitest::Runnable.runnables.shuffle
      suites.each do |suite_class|
        suite_class.runnable_methods.each do |test_method|
          method = suite_class.instance_method(test_method)
          start_line = method.source_location.last
          end_line = method.source.split("\n").size + start_line - 1
          methods_map << [test_method, start_line, end_line]
        end
      end
      methods_map
    end
  end
end

require "ostruct"
require "optparse"
require "rake/file_list"
require "method_source"

module Rails
  class TestRunner
    class Options
      def self.parse(args)
        options = { backtrace: false, name: nil, environment: "test" }

        opt_parser = ::OptionParser.new do |opts|
          opts.banner = "Usage: bin/rails test [options] [file or directory]"

          opts.separator ""
          opts.on("-e", "--environment [ENV]",
                  "run tests in the ENV environment") do |env|
            options[:environment] = env.strip
          end
          opts.separator ""
          opts.separator "Filter options:"
          opts.separator ""
          opts.separator <<-DESC
  You can run a single test by appending the line number to filename:

    bin/rails test test/models/user_test.rb:27

          DESC

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

        options[:patterns] = []
        while arg = args.shift
          if (file_and_line = arg.split(':')).size > 1
            options[:filename], options[:line] = file_and_line
            options[:filename] = File.expand_path options[:filename]
            options[:line] &&= options[:line].to_i
          else
            arg = arg.gsub(':', '')
            if Dir.exists?("#{arg}")
              options[:patterns] << File.expand_path("#{arg}/**/*_test.rb")
            elsif File.file?(arg)
              options[:patterns] << File.expand_path(arg)
            end
          end
        end
        options
      end
    end

    def initialize(options = {})
      @options = options
    end

    def self.run(arguments)
      options = Rails::TestRunner::Options.parse(arguments)
      Rails::TestRunner.new(options).run
    end

    def run
      $rails_test_runner = self
      ENV["RAILS_ENV"] = @options[:environment]
      run_tests
    end

    def find_method
      return @options[:name] if @options[:name]
      return unless @options[:line]
      method = test_methods.find do |location, test_method, start_line, end_line|
        location == @options[:filename] &&
          (start_line..end_line).include?(@options[:line].to_i)
      end
      method[1] if method
    end

    def show_backtrace?
      @options[:backtrace]
    end

    def test_files
      return [@options[:filename]] if @options[:filename]
      if @options[:patterns] && @options[:patterns].count > 0
        pattern = @options[:patterns]
      else
        pattern = "test/**/*_test.rb"
      end
      Rake::FileList[pattern]
    end

    private
    def run_tests
      test_files.to_a.each do |file|
        require File.expand_path file
      end
    end

    def test_methods
      methods_map = []
      suites = Minitest::Runnable.runnables.shuffle
      suites.each do |suite_class|
        suite_class.runnable_methods.each do |test_method|
          method = suite_class.instance_method(test_method)
          location = method.source_location
          start_line = location.last
          end_line = method.source.split("\n").size + start_line - 1
          methods_map << [location.first, test_method, start_line, end_line]
        end
      end
      methods_map
    end
  end
end

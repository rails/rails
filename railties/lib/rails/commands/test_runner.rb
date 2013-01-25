require 'optparse'
require 'minitest/unit'

module Rails
  # Handling the all the logic behind +rails test+ command.
  class TestRunner
    class << self
      # Parse the test suite name from the arguments array and pass in a list
      # of file to a new +TestRunner+ object, then invoke the evaluation. If
      # the argument is not a test suite name, it will be treated as a file
      # name and passed to the +TestRunner+ instance right away.
      def start(arguments)
        case arguments.first
        when nil
          new(Dir['test/**/*_test.rb']).run
        when 'models'
          new(Dir['test/models/**/*_test.rb']).run
        when 'helpers'
          new(Dir['test/helpers/**/*_test.rb']).run
        when 'units'
          new(Dir['test/{models,helpers,unit}/**/*_test.rb']).run
        when 'controllers'
          new(Dir['test/controllers/**/*_test.rb']).run
        when 'mailers'
          new(Dir['test/mailers/**/*_test.rb']).run
        when 'functionals'
          new(Dir['test/{controllers,mailers,functional}/**/*_test.rb']).run
        when 'integration'
          new(Dir['test/integration/**/*_test.rb']).run
        else
          new(arguments).run
        end
      end

      # Print out the help message which listed all of the test suite names.
      def help_message
        puts "Usage: rails test [path to test file(s) or test suite type]"
        puts ""
        puts "Run single test file, or a test suite, under Rails'"
        puts "environment. If the file name(s) or suit name is omitted,"
        puts "Rails will run all the test suites."
        puts ""
        puts "Support types of test suites:"
        puts "-------------------------------------------------------------"
        puts "* models (test/models/**/*)"
        puts "* helpers (test/helpers/**/*)"
        puts "* units (test/{models,helpers,unit}/**/*"
        puts "* controllers (test/controllers/**/*)"
        puts "* mailers (test/mailers/**/*)"
        puts "* functionals (test/{controllers,mailers,functional}/**/*)"
        puts "* integration (test/integration/**/*)"
        puts "-------------------------------------------------------------"
      end
    end

    # Create a new +TestRunner+ object with a list of test file paths.
    def initialize(files)
      @files = files
      Rake::Task['test:prepare'].invoke
      MiniTest::Unit.output = SilentUntilSyncStream.new(MiniTest::Unit.output)
    end

    # Run the test files by evaluate each of them.
    def run
      @files.each { |filename| load(filename) }
    end

    # A null stream object which ignores everything until +sync+ has been set
    # to true. This is only to be used to silence unnecessary output from
    # MiniTest, as MiniTest calls +output.sync = true+ right before output the
    # first test result.
    class SilentUntilSyncStream < File
      # Create a +SilentUntilSyncStream+ object by given a stream object that
      # this stream should set +MiniTest::Unit.output+ to after +sync+ has been
      # set to true.
      def initialize(target_stream)
        @target_stream = target_stream
        super(File::NULL, 'w')
      end

      # Swap +MiniTest::Unit.output+ to another stream when +sync+ is true.
      def sync=(sync)
        if sync
          @target_stream.sync = true
          MiniTest::Unit.output = @target_stream
        end

        super
      end
    end
  end
end

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
      def start(files, options = {})
        original_fixtures_options = options.delete(:fixtures)
        options[:fixtures] = true

        case files.first
        when nil
          new(Dir['test/**/*_test.rb'], options).run
        when 'models'
          new(Dir['test/models/**/*_test.rb'], options).run
        when 'helpers'
          new(Dir['test/helpers/**/*_test.rb'], options).run
        when 'units'
          new(Dir['test/{models,helpers,unit}/**/*_test.rb'], options).run
        when 'controllers'
          new(Dir['test/controllers/**/*_test.rb'], options).run
        when 'mailers'
          new(Dir['test/mailers/**/*_test.rb'], options).run
        when 'functionals'
          new(Dir['test/{controllers,mailers,functional}/**/*_test.rb'], options).run
        when 'integration'
          new(Dir['test/integration/**/*_test.rb'], options).run
        else
          options[:fixtures] = original_fixtures_options
          new(files, options).run
        end
      end

      # Parse arguments and set them as option flags
      def parse_arguments(arguments)
        options = {}
        orig_arguments = arguments.dup

        OptionParser.new do |opts|
          opts.banner = "Usage: rails test [path to test file(s) or test suite type]"

          opts.separator ""
          opts.separator "Run single test file, or a test suite, under Rails'"
          opts.separator "environment. If the file name(s) or suit name is omitted,"
          opts.separator "Rails will run all the test suites."
          opts.separator ""
          opts.separator "Specific options:"

          opts.on '-h', '--help', 'Display this help.' do
            puts opts
            exit
          end

          opts.on '-f', '--fixtures', 'Load fixtures in test/fixtures/ before running the tests' do
            options[:fixtures] = true
          end

          opts.on '-s', '--seed SEED', Integer, "Sets random seed" do |m|
            options[:seed] = m.to_i
          end

          opts.on '-v', '--verbose', "Verbose. Show progress processing files." do
            options[:verbose] = true
          end

          opts.on '-n', '--name PATTERN', "Filter test names on pattern (e.g. /foo/)" do |a|
            options[:filter] = a
          end

          opts.separator ""
          opts.separator "Support types of test suites:"
          opts.separator "-------------------------------------------------------------"
          opts.separator "* models (test/models/**/*)"
          opts.separator "* helpers (test/helpers/**/*)"
          opts.separator "* units (test/{models,helpers,unit}/**/*"
          opts.separator "* controllers (test/controllers/**/*)"
          opts.separator "* mailers (test/mailers/**/*)"
          opts.separator "* functionals (test/{controllers,mailers,functional}/**/*)"
          opts.separator "* integration (test/integration/**/*)"
          opts.separator "-------------------------------------------------------------"

          opts.parse! arguments
          orig_arguments -= arguments
        end
        options
      end
    end

    # Create a new +TestRunner+ object with a list of test file paths.
    def initialize(files, options)
      @files = files
      Rake::Task['test:prepare'].invoke

      if options.delete(:fixtures)
        if defined?(ActiveRecord::Base)
          ActiveSupport::TestCase.send :include, ActiveRecord::TestFixtures
          ActiveSupport::TestCase.fixture_path = "#{Rails.root}/test/fixtures/"
          ActiveSupport::TestCase.fixtures :all
        end
      end

      MiniTest::Unit.runner.options = options
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

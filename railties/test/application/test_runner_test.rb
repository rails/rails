require 'isolation/abstract_unit'

module ApplicationTests
  class TestRunnerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      create_schema
    end

    def teardown
      teardown_app
    end

    def test_should_not_display_heading
      create_test_file
      run_test_command.tap do |output|
        assert_no_match /Run options:/, output
        assert_no_match /Running tests:/, output
      end
    end

    def test_run_shortcut
      create_test_file :models, 'foo'
      output = Dir.chdir(app_path) { `bundle exec rails t test/models/foo_test.rb` }
      assert_match /1 tests, 1 assertions, 0 failures/, output
    end

    def test_run_single_file
      create_test_file :models, 'foo'
      assert_match /1 tests, 1 assertions, 0 failures/, run_test_command("test/models/foo_test.rb")
    end

    def test_run_multiple_files
      create_test_file :models,  'foo'
      create_test_file :models,  'bar'
      assert_match /2 tests, 2 assertions, 0 failures/, run_test_command("test/models/foo_test.rb test/models/bar_test.rb")
    end

    def test_run_file_with_syntax_error
      app_file 'test/models/error_test.rb', <<-RUBY
        require 'test_helper'
        def; end
      RUBY

      error_stream = Tempfile.new('error')
      redirect_stderr(error_stream) { run_test_command('test/models/error_test.rb') }
      assert_match /SyntaxError/, error_stream.read
    end

    def test_invoke_rake_test_prepare
      app_file "lib/tasks/test.rake", <<-RUBY
        namespace :test do
          task :prepare do
            puts "Hello World"
          end
        end
      RUBY
      create_test_file
      assert_match /Hello World/, run_test_command
    end

    def test_run_models
      create_test_file :models, 'foo'
      create_test_file :models, 'bar'
      create_test_file :controllers, 'foobar_controller'
      run_test_command("models").tap do |output|
        assert_match /FooTest/, output
        assert_match /BarTest/, output
        assert_match /2 tests, 2 assertions, 0 failures/, output
      end
    end

    def test_run_helpers
      create_test_file :helpers, 'foo_helper'
      create_test_file :helpers, 'bar_helper'
      create_test_file :controllers, 'foobar_controller'
      run_test_command('helpers').tap do |output|
        assert_match /FooHelperTest/, output
        assert_match /BarHelperTest/, output
        assert_match /2 tests, 2 assertions, 0 failures/, output
      end
    end

    def test_run_units
      create_test_file :models, 'foo'
      create_test_file :helpers, 'bar_helper'
      create_test_file :unit, 'baz_unit'
      create_test_file :controllers, 'foobar_controller'
      run_test_command('units').tap do |output|
        assert_match /FooTest/, output
        assert_match /BarHelperTest/, output
        assert_match /BazUnitTest/, output
        assert_match /3 tests, 3 assertions, 0 failures/, output
      end
    end

    def test_run_controllers
      create_test_file :controllers, 'foo_controller'
      create_test_file :controllers, 'bar_controller'
      create_test_file :models, 'foo'
      run_test_command('controllers').tap do |output|
        assert_match /FooControllerTest/, output
        assert_match /BarControllerTest/, output
        assert_match /2 tests, 2 assertions, 0 failures/, output
      end
    end

    def test_run_mailers
      create_test_file :mailers, 'foo_mailer'
      create_test_file :mailers, 'bar_mailer'
      create_test_file :models, 'foo'
      run_test_command('mailers').tap do |output|
        assert_match /FooMailerTest/, output
        assert_match /BarMailerTest/, output
        assert_match /2 tests, 2 assertions, 0 failures/, output
      end
    end

    def test_run_functionals
      create_test_file :mailers, 'foo_mailer'
      create_test_file :controllers, 'bar_controller'
      create_test_file :functional, 'baz_functional'
      create_test_file :models, 'foo'
      run_test_command('functionals').tap do |output|
        assert_match /FooMailerTest/, output
        assert_match /BarControllerTest/, output
        assert_match /BazFunctionalTest/, output
        assert_match /3 tests, 3 assertions, 0 failures/, output
      end
    end

    def test_run_integration
      create_test_file :integration, 'foo_integration'
      create_test_file :models, 'foo'
      run_test_command('integration').tap do |output|
        assert_match /FooIntegration/, output
        assert_match /1 tests, 1 assertions, 0 failures/, output
      end
    end

    def test_run_whole_suite
      types = [:models, :helpers, :unit, :controllers, :mailers, :functional, :integration]
      types.each { |type| create_test_file type, "foo_#{type}" }
      run_test_command('') .tap do |output|
        types.each { |type| assert_match /Foo#{type.to_s.camelize}Test/, output }
        assert_match /7 tests, 7 assertions, 0 failures/, output
      end
    end

    def test_run_named_test
      app_file 'test/unit/chu_2_koi_test.rb', <<-RUBY
        require 'test_helper'

        class Chu2KoiTest < ActiveSupport::TestCase
          def test_rikka
            puts 'Rikka'
          end

          def test_sanae
            puts 'Sanae'
          end
        end
      RUBY

      run_test_command('test/unit/chu_2_koi_test.rb -n test_rikka').tap do |output|
        assert_match /Rikka/, output
        assert_no_match /Sanae/, output
      end
    end

    private
      def run_test_command(arguments = 'test/unit/test_test.rb')
        Dir.chdir(app_path) { `bundle exec rails test #{arguments}` }
      end

      def create_schema
        app_file 'db/schema.rb', ''
      end

      def redirect_stderr(target_stream)
        previous_stderr = STDERR.dup
        $stderr.reopen(target_stream)
        yield
        target_stream.rewind
      ensure
        $stderr = previous_stderr
      end

      def create_test_file(path = :unit, name = 'test')
        app_file "test/#{path}/#{name}_test.rb", <<-RUBY
          require 'test_helper'

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_truth
              puts "#{name.camelize}Test"
              assert true
            end
          end
        RUBY
      end
  end
end

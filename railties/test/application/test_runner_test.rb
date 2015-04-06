require 'isolation/abstract_unit'
require 'active_support/core_ext/string/strip'

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

    def test_run_in_test_environment
      app_file 'test/unit/env_test.rb', <<-RUBY
        require 'test_helper'

        class EnvTest < ActiveSupport::TestCase
          def test_env
            puts "Current Environment: \#{Rails.env}"
          end
        end
      RUBY

      assert_match "Current Environment: test", run_test_command('test/unit/env_test.rb')
    end

    def test_run_single_file
      create_test_file :models, 'foo'
      create_test_file :models, 'bar'
      assert_match "1 runs, 1 assertions, 0 failures", run_test_command("test/models/foo_test.rb")
    end

    def test_run_multiple_files
      create_test_file :models,  'foo'
      create_test_file :models,  'bar'
      assert_match "2 runs, 2 assertions, 0 failures", run_test_command("test/models/foo_test.rb test/models/bar_test.rb")
    end

    def test_run_file_with_syntax_error
      app_file 'test/models/error_test.rb', <<-RUBY
        require 'test_helper'
        def; end
      RUBY

      error = capture(:stderr) { run_test_command('test/models/error_test.rb') }
      assert_match "syntax error", error
    end

    def test_run_models
      create_test_file :models, 'foo'
      create_test_file :models, 'bar'
      create_test_file :controllers, 'foobar_controller'
      run_test_command("test/models").tap do |output|
        assert_match "FooTest", output
        assert_match "BarTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_helpers
      create_test_file :helpers, 'foo_helper'
      create_test_file :helpers, 'bar_helper'
      create_test_file :controllers, 'foobar_controller'
      run_test_command("test/helpers").tap do |output|
        assert_match "FooHelperTest", output
        assert_match "BarHelperTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_units
      skip "we no longer have the concept of unit tests. Just different directories..."
      create_test_file :models, 'foo'
      create_test_file :helpers, 'bar_helper'
      create_test_file :unit, 'baz_unit'
      create_test_file :controllers, 'foobar_controller'
      run_test_units_command.tap do |output|
        assert_match "FooTest", output
        assert_match "BarHelperTest", output
        assert_match "BazUnitTest", output
        assert_match "3 runs, 3 assertions, 0 failures", output
      end
    end

    def test_run_controllers
      create_test_file :controllers, 'foo_controller'
      create_test_file :controllers, 'bar_controller'
      create_test_file :models, 'foo'
      run_test_command("test/controllers").tap do |output|
        assert_match "FooControllerTest", output
        assert_match "BarControllerTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_mailers
      create_test_file :mailers, 'foo_mailer'
      create_test_file :mailers, 'bar_mailer'
      create_test_file :models, 'foo'
      run_test_command("test/mailers").tap do |output|
        assert_match "FooMailerTest", output
        assert_match "BarMailerTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_jobs
      create_test_file :jobs, 'foo_job'
      create_test_file :jobs, 'bar_job'
      create_test_file :models, 'foo'
      run_test_command("test/jobs").tap do |output|
        assert_match "FooJobTest", output
        assert_match "BarJobTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_functionals
      skip "we no longer have the concept of functional tests. Just different directories..."
      create_test_file :mailers, 'foo_mailer'
      create_test_file :controllers, 'bar_controller'
      create_test_file :functional, 'baz_functional'
      create_test_file :models, 'foo'
      run_test_functionals_command.tap do |output|
        assert_match "FooMailerTest", output
        assert_match "BarControllerTest", output
        assert_match "BazFunctionalTest", output
        assert_match "3 runs, 3 assertions, 0 failures", output
      end
    end

    def test_run_integration
      create_test_file :integration, 'foo_integration'
      create_test_file :models, 'foo'
      run_test_command("test/integration").tap do |output|
        assert_match "FooIntegration", output
        assert_match "1 runs, 1 assertions, 0 failures", output
      end
    end

    def test_run_all_suites
      suites = [:models, :helpers, :unit, :controllers, :mailers, :functional, :integration, :jobs]
      suites.each { |suite| create_test_file suite, "foo_#{suite}" }
      run_test_command('') .tap do |output|
        suites.each { |suite| assert_match "Foo#{suite.to_s.camelize}Test", output }
        assert_match "8 runs, 8 assertions, 0 failures", output
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

      run_test_command('-n test_rikka test/unit/chu_2_koi_test.rb').tap do |output|
        assert_match "Rikka", output
        assert_no_match "Sanae", output
      end
    end

    def test_run_matched_test
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

      run_test_command('-p rikka test/unit/chu_2_koi_test.rb').tap do |output|
        assert_match "Rikka", output
        assert_no_match "Sanae", output
      end
    end

    def test_load_fixtures_when_running_test_suites
      create_model_with_fixture
      suites = [:models, :helpers, :controllers, :mailers, :integration]

      suites.each do |suite, directory|
        directory ||= suite
        create_fixture_test directory
        assert_match "3 users", run_test_command("test/#{suite}")
        Dir.chdir(app_path) { FileUtils.rm_f "test/#{directory}" }
      end
    end

    def test_run_with_model
      skip "These feel a bit odd. Not sure we should keep supporting them."
      create_model_with_fixture
      create_fixture_test 'models', 'user'
      assert_match "3 users", run_task(["test models/user"])
      assert_match "3 users", run_task(["test app/models/user.rb"])
    end

    def test_run_different_environment_using_env_var
      skip "no longer possible. Running tests in a different environment should be explicit"
      app_file 'test/unit/env_test.rb', <<-RUBY
        require 'test_helper'

        class EnvTest < ActiveSupport::TestCase
          def test_env
            puts Rails.env
          end
        end
      RUBY

      ENV['RAILS_ENV'] = 'development'
      assert_match "development", run_test_command('test/unit/env_test.rb')
    end

    def test_run_different_environment
      env = "development"
      app_file 'test/unit/env_test.rb', <<-RUBY
        require 'test_helper'

        class EnvTest < ActiveSupport::TestCase
          def test_env
            puts Rails.env
          end
        end
      RUBY

      assert_match env, run_test_command("-e #{env} test/unit/env_test.rb")
    end

    def test_generated_scaffold_works_with_rails_test
      create_scaffold
      assert_match "0 failures, 0 errors, 0 skips", run_test_command('')
    end

    private
      def run_test_command(arguments = 'test/unit/test_test.rb')
        Dir.chdir(app_path) { `bin/rails t #{arguments}` }
      end

      def create_model_with_fixture
        script 'generate model user name:string'

        app_file 'test/fixtures/users.yml', <<-YAML.strip_heredoc
          vampire:
            id: 1
            name: Koyomi Araragi
          crab:
            id: 2
            name: Senjougahara Hitagi
          cat:
            id: 3
            name: Tsubasa Hanekawa
        YAML

        run_migration
      end

      def create_fixture_test(path = :unit, name = 'test')
        app_file "test/#{path}/#{name}_test.rb", <<-RUBY
          require 'test_helper'

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_fixture
              puts "\#{User.count} users (\#{__FILE__})"
            end
          end
        RUBY
      end

      def create_schema
        app_file 'db/schema.rb', ''
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

      def create_scaffold
        script 'generate scaffold user name:string'
        Dir.chdir(app_path) { File.exist?('app/models/user.rb') }
        run_migration
      end

      def run_migration
        Dir.chdir(app_path) { `bundle exec rake db:migrate` }
      end
  end
end

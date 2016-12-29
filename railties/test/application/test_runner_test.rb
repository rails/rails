require "isolation/abstract_unit"
require "active_support/core_ext/string/strip"
require "env_helpers"

module ApplicationTests
  class TestRunnerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    def setup
      build_app
      create_schema
    end

    def teardown
      teardown_app
    end

    def test_run_single_file
      create_test_file :models, "foo"
      create_test_file :models, "bar"
      assert_match "1 runs, 1 assertions, 0 failures", run_test_command("test/models/foo_test.rb")
    end

    def test_run_multiple_files
      create_test_file :models,  "foo"
      create_test_file :models,  "bar"
      assert_match "2 runs, 2 assertions, 0 failures", run_test_command("test/models/foo_test.rb test/models/bar_test.rb")
    end

    def test_run_file_with_syntax_error
      app_file "test/models/error_test.rb", <<-RUBY
        require 'test_helper'
        def; end
      RUBY

      error = capture(:stderr) { run_test_command("test/models/error_test.rb") }
      assert_match "syntax error", error
    end

    def test_run_models
      create_test_file :models, "foo"
      create_test_file :models, "bar"
      create_test_file :controllers, "foobar_controller"
      run_test_command("test/models").tap do |output|
        assert_match "FooTest", output
        assert_match "BarTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_helpers
      create_test_file :helpers, "foo_helper"
      create_test_file :helpers, "bar_helper"
      create_test_file :controllers, "foobar_controller"
      run_test_command("test/helpers").tap do |output|
        assert_match "FooHelperTest", output
        assert_match "BarHelperTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_units
      skip "we no longer have the concept of unit tests. Just different directories..."
      create_test_file :models, "foo"
      create_test_file :helpers, "bar_helper"
      create_test_file :unit, "baz_unit"
      create_test_file :controllers, "foobar_controller"
      run_test_units_command.tap do |output|
        assert_match "FooTest", output
        assert_match "BarHelperTest", output
        assert_match "BazUnitTest", output
        assert_match "3 runs, 3 assertions, 0 failures", output
      end
    end

    def test_run_controllers
      create_test_file :controllers, "foo_controller"
      create_test_file :controllers, "bar_controller"
      create_test_file :models, "foo"
      run_test_command("test/controllers").tap do |output|
        assert_match "FooControllerTest", output
        assert_match "BarControllerTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_mailers
      create_test_file :mailers, "foo_mailer"
      create_test_file :mailers, "bar_mailer"
      create_test_file :models, "foo"
      run_test_command("test/mailers").tap do |output|
        assert_match "FooMailerTest", output
        assert_match "BarMailerTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_jobs
      create_test_file :jobs, "foo_job"
      create_test_file :jobs, "bar_job"
      create_test_file :models, "foo"
      run_test_command("test/jobs").tap do |output|
        assert_match "FooJobTest", output
        assert_match "BarJobTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_functionals
      skip "we no longer have the concept of functional tests. Just different directories..."
      create_test_file :mailers, "foo_mailer"
      create_test_file :controllers, "bar_controller"
      create_test_file :functional, "baz_functional"
      create_test_file :models, "foo"
      run_test_functionals_command.tap do |output|
        assert_match "FooMailerTest", output
        assert_match "BarControllerTest", output
        assert_match "BazFunctionalTest", output
        assert_match "3 runs, 3 assertions, 0 failures", output
      end
    end

    def test_run_integration
      create_test_file :integration, "foo_integration"
      create_test_file :models, "foo"
      run_test_command("test/integration").tap do |output|
        assert_match "FooIntegration", output
        assert_match "1 runs, 1 assertions, 0 failures", output
      end
    end

    def test_run_all_suites
      suites = [:models, :helpers, :unit, :controllers, :mailers, :functional, :integration, :jobs]
      suites.each { |suite| create_test_file suite, "foo_#{suite}" }
      run_test_command("") .tap do |output|
        suites.each { |suite| assert_match "Foo#{suite.to_s.camelize}Test", output }
        assert_match "8 runs, 8 assertions, 0 failures", output
      end
    end

    def test_run_named_test
      app_file "test/unit/chu_2_koi_test.rb", <<-RUBY
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

      run_test_command("-n test_rikka test/unit/chu_2_koi_test.rb").tap do |output|
        assert_match "Rikka", output
        assert_no_match "Sanae", output
      end
    end

    def test_run_matched_test
      app_file "test/unit/chu_2_koi_test.rb", <<-RUBY
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

      run_test_command("-n /rikka/ test/unit/chu_2_koi_test.rb").tap do |output|
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
      create_fixture_test "models", "user"
      assert_match "3 users", run_task(["test models/user"])
      assert_match "3 users", run_task(["test app/models/user.rb"])
    end

    def test_run_different_environment_using_env_var
      skip "no longer possible. Running tests in a different environment should be explicit"
      app_file "test/unit/env_test.rb", <<-RUBY
        require 'test_helper'

        class EnvTest < ActiveSupport::TestCase
          def test_env
            puts Rails.env
          end
        end
      RUBY

      ENV["RAILS_ENV"] = "development"
      assert_match "development", run_test_command("test/unit/env_test.rb")
    end

    def test_run_in_test_environment_by_default
      create_env_test

      assert_match "Current Environment: test", run_test_command("test/unit/env_test.rb")
    end

    def test_run_different_environment
      create_env_test

      assert_match "Current Environment: development",
        run_test_command("-e development test/unit/env_test.rb")
    end

    def test_generated_scaffold_works_with_rails_test
      create_scaffold
      assert_match "0 failures, 0 errors, 0 skips", run_test_command("")
    end

    def test_generated_controller_works_with_rails_test
      create_controller
      assert_match "0 failures, 0 errors, 0 skips", run_test_command("")
    end

    def test_run_multiple_folders
      create_test_file :models, "account"
      create_test_file :controllers, "accounts_controller"

      run_test_command("test/models test/controllers").tap do |output|
        assert_match "AccountTest", output
        assert_match "AccountsControllerTest", output
        assert_match "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_run_with_ruby_command
      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          test 'declarative syntax works' do
            puts 'PostTest'
            assert true
          end
        end
      RUBY

      Dir.chdir(app_path) do
        `ruby -Itest test/models/post_test.rb`.tap do |output|
          assert_match "PostTest", output
          assert_no_match "is already defined in", output
        end
      end
    end

    def test_mix_files_and_line_filters
      create_test_file :models, "account"
      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          def test_post
            puts 'PostTest'
            assert true
          end

          def test_line_filter_does_not_run_this
            assert true
          end
        end
      RUBY

      run_test_command("test/models/account_test.rb test/models/post_test.rb:4").tap do |output|
        assert_match "AccountTest", output
        assert_match "PostTest", output
        assert_match "2 runs, 2 assertions", output
      end
    end

    def test_more_than_one_line_filter
      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          test "first filter" do
            puts 'PostTest:FirstFilter'
            assert true
          end

          test "second filter" do
            puts 'PostTest:SecondFilter'
            assert true
          end

          test "test line filter does not run this" do
            assert true
          end
        end
      RUBY

      run_test_command("test/models/post_test.rb:4:9").tap do |output|
        assert_match "PostTest:FirstFilter", output
        assert_match "PostTest:SecondFilter", output
        assert_match "2 runs, 2 assertions", output
      end
    end

    def test_more_than_one_line_filter_with_multiple_files
      app_file "test/models/account_test.rb", <<-RUBY
        require 'test_helper'

        class AccountTest < ActiveSupport::TestCase
          test "first filter" do
            puts 'AccountTest:FirstFilter'
            assert true
          end

          test "second filter" do
            puts 'AccountTest:SecondFilter'
            assert true
          end

          test "line filter does not run this" do
            assert true
          end
        end
      RUBY

      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          test "first filter" do
            puts 'PostTest:FirstFilter'
            assert true
          end

          test "second filter" do
            puts 'PostTest:SecondFilter'
            assert true
          end

          test "line filter does not run this" do
            assert true
          end
        end
      RUBY

      run_test_command("test/models/account_test.rb:4:9 test/models/post_test.rb:4:9").tap do |output|
        assert_match "AccountTest:FirstFilter", output
        assert_match "AccountTest:SecondFilter", output
        assert_match "PostTest:FirstFilter", output
        assert_match "PostTest:SecondFilter", output
        assert_match "4 runs, 4 assertions", output
      end
    end

    def test_multiple_line_filters
      create_test_file :models, "account"
      create_test_file :models, "post"

      run_test_command("test/models/account_test.rb:4 test/models/post_test.rb:4").tap do |output|
        assert_match "AccountTest", output
        assert_match "PostTest", output
      end
    end

    def test_line_filters_trigger_only_one_runnable
      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          test 'truth' do
            assert true
          end
        end

        class SecondPostTest < ActiveSupport::TestCase
          test 'truth' do
            assert false, 'ran second runnable'
          end
        end
      RUBY

      # Pass seed guaranteeing failure.
      run_test_command("test/models/post_test.rb:4 --seed 30410").tap do |output|
        assert_no_match "ran second runnable", output
        assert_match "1 runs, 1 assertions", output
      end
    end

    def test_line_filter_with_minitest_string_filter
      app_file "test/models/post_test.rb", <<-RUBY
        require 'test_helper'

        class PostTest < ActiveSupport::TestCase
          test 'by line' do
            puts 'by line'
            assert true
          end

          test 'by name' do
            puts 'by name'
            assert true
          end
        end
      RUBY

      run_test_command("test/models/post_test.rb:4 -n test_by_name").tap do |output|
        assert_match "by line", output
        assert_match "by name", output
        assert_match "2 runs, 2 assertions", output
      end
    end

    def test_shows_filtered_backtrace_by_default
      create_backtrace_test

      assert_match "Rails::BacktraceCleaner", run_test_command("test/unit/backtrace_test.rb")
    end

    def test_backtrace_option
      create_backtrace_test

      assert_match "Minitest::BacktraceFilter", run_test_command("test/unit/backtrace_test.rb -b")
      assert_match "Minitest::BacktraceFilter",
        run_test_command("test/unit/backtrace_test.rb --backtrace")
    end

    def test_show_full_backtrace_using_backtrace_environment_variable
      create_backtrace_test

      switch_env "BACKTRACE", "true" do
        assert_match "Minitest::BacktraceFilter", run_test_command("test/unit/backtrace_test.rb")
      end
    end

    def test_run_app_without_rails_loaded
      # Simulate a real Rails app boot.
      app_file "config/boot.rb", <<-RUBY
        ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

        require 'bundler/setup' # Set up gems listed in the Gemfile.
      RUBY

      assert_match "0 runs, 0 assertions", run_test_command("")
    end

    def test_output_inline_by_default
      create_test_file :models, "post", pass: false

      output = run_test_command("test/models/post_test.rb")
      expect = %r{Running:\n\nPostTest\nF\n\nFailure:\nPostTest#test_truth \[[^\]]+test/models/post_test.rb:6\]:\nwups!\n\nbin/rails test test/models/post_test.rb:4\n\n\n\n}
      assert_match expect, output
    end

    def test_only_inline_failure_output
      create_test_file :models, "post", pass: false

      output = run_test_command("test/models/post_test.rb")
      assert_match %r{Finished in.*\n\n1 runs, 1 assertions}, output
    end

    def test_fail_fast
      create_test_file :models, "post", pass: false

      assert_match(/Interrupt/,
        capture(:stderr) { run_test_command("test/models/post_test.rb --fail-fast") })
    end

    def test_raise_error_when_specified_file_does_not_exist
      error = capture(:stderr) { run_test_command("test/not_exists.rb") }
      assert_match(%r{cannot load such file.+test/not_exists\.rb}, error)
    end

    def test_pass_TEST_env_on_rake_test
      create_test_file :models, "account"
      create_test_file :models, "post", pass: false
      # This specifically verifies TEST for backwards compatibility with rake test
      # as bin/rails test already supports running tests from a single file more cleanly.
      output = Dir.chdir(app_path) { `bin/rake test TEST=test/models/post_test.rb` }

      assert_match "PostTest", output, "passing TEST= should run selected test"
      assert_no_match "AccountTest", output, "passing TEST= should only run selected test"
      assert_match "1 runs, 1 assertions", output
    end

    def test_pass_rake_options
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake --rakefile Rakefile --trace=stdout test` }

      assert_match "1 runs, 1 assertions", output
      assert_match "Execute test", output
    end

    def test_rails_db_create_all_restores_db_connection
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rails db:create:all db:migrate && echo ".tables" | rails dbconsole` }
      assert_match "ar_internal_metadata", output, "tables should be dumped"
    end

    def test_rails_db_create_all_restores_db_connection_after_drop
      create_test_file :models, "account"
      Dir.chdir(app_path) { `bin/rails db:create:all` } # create all to avoid warnings
      output = Dir.chdir(app_path) { `bin/rails db:drop:all db:create:all db:migrate && echo ".tables" | rails dbconsole` }
      assert_match "ar_internal_metadata", output, "tables should be dumped"
    end

    def test_rake_passes_TESTOPTS_to_minitest
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake test TESTOPTS=-v` }
      assert_match "AccountTest#test_truth", output, "passing TEST= should run selected test"
    end

    def test_rake_passes_multiple_TESTOPTS_to_minitest
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake test TESTOPTS='-v --seed=1234'` }
      assert_match "AccountTest#test_truth", output, "passing TEST= should run selected test"
      assert_match "seed=1234", output, "passing TEST= should run selected test"
    end

    private
      def run_test_command(arguments = "test/unit/test_test.rb")
        Dir.chdir(app_path) { `bin/rails t #{arguments}` }
      end

      def create_model_with_fixture
        script "generate model user name:string"

        app_file "test/fixtures/users.yml", <<-YAML.strip_heredoc
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

      def create_fixture_test(path = :unit, name = "test")
        app_file "test/#{path}/#{name}_test.rb", <<-RUBY
          require 'test_helper'

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_fixture
              puts "\#{User.count} users (\#{__FILE__})"
            end
          end
        RUBY
      end

      def create_backtrace_test
        app_file "test/unit/backtrace_test.rb", <<-RUBY
          require 'test_helper'

          class BacktraceTest < ActiveSupport::TestCase
            def test_backtrace
              puts Minitest.backtrace_filter
            end
          end
        RUBY
      end

      def create_schema
        app_file "db/schema.rb", ""
      end

      def create_test_file(path = :unit, name = "test", pass: true)
        app_file "test/#{path}/#{name}_test.rb", <<-RUBY
          require 'test_helper'

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_truth
              puts "#{name.camelize}Test"
              assert #{pass}, 'wups!'
            end
          end
        RUBY
      end

      def create_env_test
        app_file "test/unit/env_test.rb", <<-RUBY
          require 'test_helper'

          class EnvTest < ActiveSupport::TestCase
            def test_env
              puts "Current Environment: \#{Rails.env}"
            end
          end
        RUBY
      end

      def create_scaffold
        script "generate scaffold user name:string"
        Dir.chdir(app_path) { File.exist?("app/models/user.rb") }
        run_migration
      end

      def create_controller
        script "generate controller admin/dashboard index"
      end

      def run_migration
        Dir.chdir(app_path) { `bin/rails db:migrate` }
      end
  end
end

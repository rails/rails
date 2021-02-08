# frozen_string_literal: true

require "isolation/abstract_unit"
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

    def test_run_via_backwards_compatibility
      require "minitest/rails_plugin"

      assert_nothing_raised do
        Minitest.run_via[:ruby] = true
      end

      assert Minitest.run_via[:ruby]
    end

    def test_run_single_file
      create_test_file :models, "foo"
      create_test_file :models, "bar"
      assert_match "1 runs, 1 assertions, 0 failures", run_test_command("test/models/foo_test.rb")
    end

    def test_run_single_file_with_absolute_path
      create_test_file :models, "foo"
      create_test_file :models, "bar"
      assert_match "1 runs, 1 assertions, 0 failures", run_test_command("#{app_path}/test/models/foo_test.rb")
    end

    def test_run_multiple_files
      create_test_file :models,  "foo"
      create_test_file :models,  "bar"
      assert_match "2 runs, 2 assertions, 0 failures", run_test_command("test/models/foo_test.rb test/models/bar_test.rb")
    end

    def test_run_multiple_files_with_absolute_paths
      create_test_file :models,  "foo"
      create_test_file :controllers,  "foobar_controller"
      create_test_file :models, "bar"

      assert_match "2 runs, 2 assertions, 0 failures", run_test_command("#{app_path}/test/models/foo_test.rb #{app_path}/test/controllers/foobar_controller_test.rb")
    end

    def test_run_file_with_syntax_error
      app_file "test/models/error_test.rb", <<-RUBY
        require "test_helper"
        def; end
      RUBY

      error = capture(:stderr) { run_test_command("test/models/error_test.rb", stderr: true) }
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
      create_test_file :models, "foo"
      create_test_file :helpers, "bar_helper"
      create_test_file :unit, "baz_unit"
      create_test_file :controllers, "foobar_controller"

      rails("test:units").tap do |output|
        assert_match "FooTest", output
        assert_match "BarHelperTest", output
        assert_match "BazUnitTest", output
        assert_match "3 runs, 3 assertions, 0 failures", output
      end
    end

    def test_run_channels
      create_test_file :channels, "foo_channel"
      create_test_file :channels, "bar_channel"

      rails("test:channels").tap do |output|
        assert_match "FooChannelTest", output
        assert_match "BarChannelTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
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

    def test_run_mailboxes
      create_test_file :mailboxes, "foo_mailbox"
      create_test_file :mailboxes, "bar_mailbox"
      create_test_file :models, "foo"

      rails("test:mailboxes").tap do |output|
        assert_match "FooMailboxTest", output
        assert_match "BarMailboxTest", output
        assert_match "2 runs, 2 assertions, 0 failures", output
      end
    end

    def test_run_functionals
      create_test_file :mailers, "foo_mailer"
      create_test_file :controllers, "bar_controller"
      create_test_file :functional, "baz_functional"
      create_test_file :models, "foo"

      rails("test:functionals").tap do |output|
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
      suites = [:models, :helpers, :unit, :channels, :controllers, :mailers, :functional, :integration, :jobs, :mailboxes]
      suites.each { |suite| create_test_file suite, "foo_#{suite}" }
      run_test_command("") .tap do |output|
        suites.each { |suite| assert_match "Foo#{suite.to_s.camelize}Test", output }
        assert_match "10 runs, 10 assertions, 0 failures", output
      end
    end

    def test_run_named_test
      app_file "test/unit/chu_2_koi_test.rb", <<-RUBY
        require "test_helper"

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
        require "test_helper"

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

    def test_run_multiple_folders_with_absolute_paths
      create_test_file :models, "account"
      create_test_file :controllers, "accounts_controller"
      create_test_file :helpers, "foo_helper"

      run_test_command("#{app_path}/test/models #{app_path}/test/controllers").tap do |output|
        assert_match "AccountTest", output
        assert_match "AccountsControllerTest", output
        assert_match "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_run_relative_path_with_trailing_slash
      create_test_file :models, "account"
      create_test_file :controllers, "accounts_controller"

      run_test_command("test/models/").tap do |output|
        assert_match "AccountTest", output
        assert_match "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_run_windows_style_path
      create_test_file :models, "account"
      create_test_file :controllers, "accounts_controller"

      # double-escape backslash -- once for Ruby and again for shelling out
      run_test_command("test\\\\models").tap do |output|
        assert_match "AccountTest", output
        assert_match "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_run_with_ruby_command
      app_file "test/models/post_test.rb", <<-RUBY
        require "test_helper"

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
        require "test_helper"

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
        require "test_helper"

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

      run_test_command("test/models/post_test.rb:4:9").tap do |output|
        assert_match "PostTest:FirstFilter", output
        assert_match "PostTest:SecondFilter", output
        assert_match "2 runs, 2 assertions", output
      end
    end

    def test_more_than_one_line_filter_with_multiple_files
      app_file "test/models/account_test.rb", <<-RUBY
        require "test_helper"

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
        require "test_helper"

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
        require "test_helper"

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
        require "test_helper"

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

    def test_run_app_without_rails_loaded
      # Simulate a real Rails app boot.
      app_file "config/boot.rb", <<-RUBY
        ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

        require "bundler/setup" # Set up gems listed in the Gemfile.
      RUBY

      assert_match "0 runs, 0 assertions", run_test_command("")
    end

    def test_output_inline_by_default
      create_test_file :models, "post", pass: false, print: false

      output = run_test_command("test/models/post_test.rb")
      expect = %r{Running:\n\nF\n\nFailure:\nPostTest#test_truth \[[^\]]+test/models/post_test.rb:6\]:\nwups!\n\nrails test test/models/post_test.rb:4\n\n\n\n}
      assert_match expect, output
    end

    def test_only_inline_failure_output
      create_test_file :models, "post", pass: false

      output = run_test_command("test/models/post_test.rb")
      assert_match %r{Finished in.*\n1 runs, 1 assertions}, output
    end

    def test_fail_fast
      create_test_file :models, "post", pass: false

      assert_match(/Interrupt/,
        capture(:stderr) { run_test_command("test/models/post_test.rb --fail-fast", stderr: true) })
    end

    def test_run_in_parallel_with_processes
      exercise_parallelization_regardless_of_machine_core_count(with: :processes)

      file_name = create_parallel_processes_test_file

      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: 1) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      output = run_test_command(file_name)

      assert_match %r{Finished in.*\n2 runs, 2 assertions}, output
      assert_no_match "create_table(:users)", output
    end

    def test_run_in_parallel_with_process_worker_crash
      exercise_parallelization_regardless_of_machine_core_count(with: :processes)

      file_name = app_file("test/models/parallel_test.rb", <<-RUBY)
        require "test_helper"

        class ParallelTest < ActiveSupport::TestCase
          def test_crash
            Kernel.exit 1
          end
        end
      RUBY

      output = run_test_command(file_name)

      assert_match %r{RuntimeError: result not reported}, output
    end

    def test_run_in_parallel_with_threads
      exercise_parallelization_regardless_of_machine_core_count(with: :threads)

      file_name = create_parallel_threads_test_file

      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: 1) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      output = run_test_command(file_name)

      assert_match %r{Finished in.*\n2 runs, 2 assertions}, output
      assert_no_match "create_table(:users)", output
    end

    def test_run_in_parallel_with_unmarshable_exception
      exercise_parallelization_regardless_of_machine_core_count(with: :processes)

      file = app_file "test/fail_test.rb", <<-RUBY
        require "test_helper"
        class FailTest < ActiveSupport::TestCase
          class BadError < StandardError
            def initialize
              super
              @proc = ->{ }
            end
          end

          test "fail" do
            raise BadError
            assert true
          end
        end
      RUBY

      output = run_test_command(file)

      assert_match "DRb::DRbRemoteError: FailTest::BadError", output
      assert_match "1 runs, 0 assertions, 0 failures, 1 errors", output
    end

    def test_run_in_parallel_with_unknown_object
      exercise_parallelization_regardless_of_machine_core_count(with: :processes)

      create_scaffold

      app_file "config/environments/test.rb", <<-RUBY
        Rails.application.configure do
          config.action_controller.allow_forgery_protection = true
          config.action_dispatch.show_exceptions = false
        end
      RUBY

      output = run_test_command("-n test_should_create_user")

      assert_match "ActionController::InvalidAuthenticityToken", output
    end

    def test_raise_error_when_specified_file_does_not_exist
      error = capture(:stderr) { run_test_command("test/not_exists.rb", stderr: true) }
      assert_match(%r{cannot load such file.+test/not_exists\.rb}, error)
    end

    def test_pass_TEST_env_on_rake_test
      create_test_file :models, "account"
      create_test_file :models, "post", pass: false
      # This specifically verifies TEST for backwards compatibility with rake test
      # as `bin/rails test` already supports running tests from a single file more cleanly.
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
      rails "db:create:all", "db:migrate"
      output = Dir.chdir(app_path) { `echo ".tables" | rails dbconsole` }
      assert_match "ar_internal_metadata", output, "tables should be dumped"
    end

    def test_rails_db_create_all_restores_db_connection_after_drop
      create_test_file :models, "account"
      rails "db:create:all" # create all to avoid warnings
      rails "db:drop:all", "db:create:all", "db:migrate"
      output = Dir.chdir(app_path) { `echo ".tables" | rails dbconsole` }
      assert_match "ar_internal_metadata", output, "tables should be dumped"
    end

    def test_rake_passes_TESTOPTS_to_minitest
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake test TESTOPTS=-v` }
      assert_match "AccountTest#test_truth", output, "passing TESTOPTS= should be sent to the test runner"
    end

    def test_running_with_ruby_gets_test_env_by_default
      # Subshells inherit `ENV`, so we need to ensure `RAILS_ENV` is set to
      # nil before we run the tests in the test app.
      re, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], nil

      file = create_test_for_env("test")
      results = Dir.chdir(app_path) {
        `ruby -Ilib:test #{file}`.each_line.map { |line| JSON.parse line }
      }
      assert_equal 1, results.length
      failures = results.first["failures"]
      flunk(failures.first) unless failures.empty?

    ensure
      ENV["RAILS_ENV"] = re
    end

    def test_running_with_ruby_can_set_env_via_cmdline
      # Subshells inherit `ENV`, so we need to ensure `RAILS_ENV` is set to
      # nil before we run the tests in the test app.
      re, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], nil

      file = create_test_for_env("development")
      results = Dir.chdir(app_path) {
        `RAILS_ENV=development ruby -Ilib:test #{file}`.each_line.map { |line| JSON.parse line }
      }
      assert_equal 1, results.length
      failures = results.first["failures"]
      flunk(failures.first) unless failures.empty?

    ensure
      ENV["RAILS_ENV"] = re
    end

    def test_rake_passes_multiple_TESTOPTS_to_minitest
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake test TESTOPTS='-v --seed=1234'` }
      assert_match "AccountTest#test_truth", output, "passing TEST= should run selected test"
      assert_match "seed=1234", output, "passing TEST= should run selected test"
    end

    def test_rake_runs_multiple_test_tasks
      create_test_file :models, "account"
      create_test_file :controllers, "accounts_controller"
      output = Dir.chdir(app_path) { `bin/rake test:models test:controllers TESTOPTS='-v'` }
      assert_match "AccountTest#test_truth", output
      assert_match "AccountsControllerTest#test_truth", output
    end

    def test_rake_db_and_test_tasks_parses_args_correctly
      create_test_file :models, "account"
      output = Dir.chdir(app_path) { `bin/rake db:migrate test:models TESTOPTS='-v' && echo ".tables" | rails dbconsole` }
      assert_match "AccountTest#test_truth", output
      assert_match "ar_internal_metadata", output
    end

    def test_rake_runs_tests_before_other_tasks_when_specified
      app_file "Rakefile", <<~RUBY, "a"
        task :echo do
          puts "echo"
        end
      RUBY
      output = Dir.chdir(app_path) { `bin/rake test echo` }
      assert_equal "echo", output.split("\n").last
    end

    def test_rake_exits_on_failure
      create_test_file :models, "post", pass: false
      app_file "Rakefile", <<~RUBY, "a"
        task :echo do
          puts "echo"
        end
      RUBY
      output = Dir.chdir(app_path) { `bin/rake test echo` }
      assert_no_match "echo", output
      assert_not_predicate $?, :success?
    end

    def test_warnings_option
      app_file "test/models/warnings_test.rb", <<-RUBY
        require "test_helper"
        def test_warnings
          a = 1
        end
      RUBY
      assert_match(/warning: assigned but unused variable/,
        capture(:stderr) { run_test_command("test/models/warnings_test.rb -w", stderr: true) })
    end

    def test_reset_sessions_before_rollback_on_system_tests
      app_file "test/system/reset_session_before_rollback_test.rb", <<-RUBY
        require "application_system_test_case"
        require "selenium/webdriver"

        class ResetSessionBeforeRollbackTest < ApplicationSystemTestCase
          def teardown_fixtures
            puts "rollback"
            super
          end

          Capybara.singleton_class.prepend(Module.new do
            def reset_sessions!
              puts "reset sessions"
              super
            end
          end)

          test "dummy" do
          end
        end
      RUBY

      run_test_command("test/system/reset_session_before_rollback_test.rb").tap do |output|
        assert_match "reset sessions\nrollback", output
        assert_match "1 runs, 0 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_reset_sessions_on_failed_system_test_screenshot
      app_file "test/system/reset_sessions_on_failed_system_test_screenshot_test.rb", <<~RUBY
        require "application_system_test_case"
        require "selenium/webdriver"

        class ResetSessionsOnFailedSystemTestScreenshotTest < ApplicationSystemTestCase
          ActionDispatch::SystemTestCase.class_eval do
            def take_failed_screenshot
              raise Capybara::CapybaraError
            end
          end

          Capybara.instance_eval do
            def reset_sessions!
              puts "Capybara.reset_sessions! called"
            end
          end

          test "dummy" do
          end
        end
      RUBY
      output = run_test_command("test/system/reset_sessions_on_failed_system_test_screenshot_test.rb")
      assert_match "Capybara.reset_sessions! called", output
    end

    def test_failed_system_test_screenshot_should_be_taken_before_other_teardown
      app_file "test/system/failed_system_test_screenshot_should_be_taken_before_other_teardown_test.rb", <<~RUBY
        require "application_system_test_case"
        require "selenium/webdriver"

        class FailedSystemTestScreenshotShouldBeTakenBeforeOtherTeardownTest < ApplicationSystemTestCase
          ActionDispatch::SystemTestCase.class_eval do
            def take_failed_screenshot
              puts "take_failed_screenshot called"
              super
            end
          end

          def teardown
            puts "test teardown called"
            super
          end

          test "dummy" do
          end
        end
      RUBY
      output = run_test_command("test/system/failed_system_test_screenshot_should_be_taken_before_other_teardown_test.rb")
      assert_match(/take_failed_screenshot called\n.*test teardown called/, output)
    end

    def test_system_tests_are_not_run_with_the_default_test_command
      app_file "test/system/dummy_test.rb", <<-RUBY
        require "application_system_test_case"

        class DummyTest < ApplicationSystemTestCase
          test "something" do
            assert true
          end
        end
      RUBY

      run_test_command("").tap do |output|
        assert_match "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips", output
      end
    end

    def test_system_tests_are_not_run_through_rake_test
      app_file "test/system/dummy_test.rb", <<-RUBY
        require "application_system_test_case"

        class DummyTest < ApplicationSystemTestCase
          test "something" do
            assert true
          end
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rake test` }
      assert_match "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips", output
    end

    def test_system_tests_are_run_through_rake_test_when_given_in_TEST
      app_file "test/system/dummy_test.rb", <<-RUBY
        require "application_system_test_case"
        require "selenium/webdriver"

        class DummyTest < ApplicationSystemTestCase
          test "something" do
            assert true
          end
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rake test TEST=test/system/dummy_test.rb` }
      assert_match "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips", output
    end

    def test_can_exclude_files_from_being_tested_via_default_rails_command_by_setting_DEFAULT_TEST_EXCLUDE_env_var
      create_test_file "smoke", "smoke_foo"

      switch_env "DEFAULT_TEST_EXCLUDE", "test/smoke/**/*_test.rb" do
        assert_match "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips", run_test_command("")
      end
    end

    def test_can_exclude_files_from_being_tested_via_rake_task_by_setting_DEFAULT_TEST_EXCLUDE_env_var
      create_test_file "smoke", "smoke_foo"

      output = Dir.chdir(app_path) { `DEFAULT_TEST_EXCLUDE="test/smoke/**/*_test.rb" bin/rake test` }
      assert_match "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips", output
    end

    private
      def run_test_command(arguments = "test/unit/test_test.rb", **opts)
        rails "t", *Shellwords.split(arguments), allow_failure: true, **opts
      end

      def create_model_with_fixture
        rails "generate", "model", "user", "name:string"

        app_file "test/fixtures/users.yml", <<~YAML
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
          require "test_helper"

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_fixture
              puts "\#{User.count} users (\#{__FILE__})"
            end
          end
        RUBY
      end

      def create_schema
        app_file "db/schema.rb", ""
      end

      def create_test_for_env(env)
        app_file "test/models/environment_test.rb", <<-RUBY
          require "test_helper"
          class JSONReporter < Minitest::AbstractReporter
            def record(result)
              puts JSON.dump(klass: result.class.name,
                             name: result.name,
                             failures: result.failures,
                             assertions: result.assertions,
                             time: result.time)
            end
          end

          def Minitest.plugin_json_reporter_init(opts)
            Minitest.reporter.reporters.clear
            Minitest.reporter.reporters << JSONReporter.new
          end

          Minitest.extensions << "rails"
          Minitest.extensions << "json_reporter"

          # Minitest uses RubyGems to find plugins, and since RubyGems
          # doesn't know about the Rails installation we're pointing at,
          # Minitest won't require the Rails minitest plugin when we run
          # these integration tests.  So we have to manually require the
          # Minitest plugin here.
          require "minitest/rails_plugin"

          class EnvironmentTest < ActiveSupport::TestCase
            def test_environment
              test_db = ActiveRecord::Base.configurations.configs_for(env_name: #{env.dump}, name: "primary").database
              db_file = ActiveRecord::Base.connection_db_config.database
              assert_match(test_db, db_file)
              assert_equal #{env.dump}, ENV["RAILS_ENV"]
            end
          end
        RUBY
      end

      def create_test_file(path = :unit, name = "test", pass: true, print: true)
        app_file "test/#{path}/#{name}_test.rb", <<-RUBY
          require "test_helper"

          class #{name.camelize}Test < ActiveSupport::TestCase
            def test_truth
              puts "#{name.camelize}Test" if #{print}
              assert #{pass}, 'wups!'
            end
          end
        RUBY
      end

      def create_parallel_processes_test_file
        app_file "test/models/parallel_test.rb", <<-RUBY
          require "test_helper"

          class ParallelTest < ActiveSupport::TestCase
            RD1, WR1 = IO.pipe
            RD2, WR2 = IO.pipe

            test "one" do
              WR1.close
              assert_equal "x", RD1.read(1) # blocks until two runs

              RD2.close
              WR2.write "y" # Allow two to run
              WR2.close
            end

            test "two" do
              RD1.close
              WR1.write "x" # Allow one to run
              WR1.close

              WR2.close
              assert_equal "y", RD2.read(1) # blocks until one runs
            end
          end
        RUBY
      end

      def create_parallel_threads_test_file
        app_file "test/models/parallel_test.rb", <<-RUBY
          require "test_helper"

          class ParallelTest < ActiveSupport::TestCase
            Q1 = Queue.new
            Q2 = Queue.new
            test "one" do
              assert_equal "x", Q1.pop # blocks until two runs

              Q2 << "y"
            end

            test "two" do
              Q1 << "x"

              assert_equal "y", Q2.pop # blocks until one runs
            end
          end
        RUBY
      end

      def exercise_parallelization_regardless_of_machine_core_count(with:)
        app_path("test/test_helper.rb") do |file_name|
          file = File.read(file_name)
          file.sub!(/parallelize\(([^)]*)\)/, "parallelize(workers: 2, with: :#{with})")
          File.write(file_name, file)
        end
      end

      def create_env_test
        app_file "test/unit/env_test.rb", <<-RUBY
          require "test_helper"

          class EnvTest < ActiveSupport::TestCase
            def test_env
              puts "Current Environment: \#{Rails.env}"
            end
          end
        RUBY
      end

      def create_scaffold
        rails "generate", "scaffold", "user", "name:string"
        assert File.exist?("#{app_path}/app/models/user.rb")
        run_migration
      end

      def create_controller
        rails "generate", "controller", "admin/dashboard", "index"
      end

      def run_migration
        rails "db:migrate"
      end
  end
end

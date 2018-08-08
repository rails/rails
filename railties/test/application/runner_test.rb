# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  class RunnerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include EnvHelpers

    def setup
      build_app

      # Lets create a model so we have something to play with
      app_file "app/models/user.rb", <<-MODEL
      class User
        def self.count
          42
        end
      end
      MODEL
    end

    def teardown
      teardown_app
    end

    def test_should_include_runner_in_shebang_line_in_help_without_option
      assert_match "/rails runner", rails("runner", allow_failure: true)
    end

    def test_should_include_runner_in_shebang_line_in_help
      assert_match "/rails runner", rails("runner", "--help")
    end

    def test_should_run_ruby_statement
      assert_match "42", rails("runner", "puts User.count")
    end

    def test_should_set_argv_when_running_code
      output = rails("runner", "puts ARGV.join(',')", "--foo", "a1", "-b", "a2", "a3", "--moo")
      assert_equal "--foo,a1,-b,a2,a3,--moo", output.chomp
    end

    def test_should_run_file
      app_file "bin/count_users.rb", <<-SCRIPT
      puts User.count
      SCRIPT

      assert_match "42", rails("runner", "bin/count_users.rb")
    end

    def test_no_minitest_loaded_in_production_mode
      app_file "bin/print_features.rb", <<-SCRIPT
      p $LOADED_FEATURES.grep(/minitest/)
      SCRIPT
      assert_match "[]", Dir.chdir(app_path) {
        `RAILS_ENV=production bin/rails runner "bin/print_features.rb"`
      }
    end

    def test_should_set_dollar_0_to_file
      app_file "bin/dollar0.rb", <<-SCRIPT
      puts $0
      SCRIPT

      assert_match "bin/dollar0.rb", rails("runner", "bin/dollar0.rb")
    end

    def test_should_set_dollar_program_name_to_file
      app_file "bin/program_name.rb", <<-SCRIPT
      puts $PROGRAM_NAME
      SCRIPT

      assert_match "bin/program_name.rb", rails("runner", "bin/program_name.rb")
    end

    def test_passes_extra_args_to_file
      app_file "bin/program_name.rb", <<-SCRIPT
      p ARGV
      SCRIPT

      assert_match %w( a b ).to_s, rails("runner", "bin/program_name.rb", "a", "b")
    end

    def test_should_run_stdin
      app_file "bin/count_users.rb", <<-SCRIPT
      puts User.count
      SCRIPT

      assert_match "42", Dir.chdir(app_path) { `cat bin/count_users.rb | bin/rails runner -` }
    end

    def test_with_hook
      add_to_config <<-RUBY
        runner do |app|
          app.config.ran = true
        end
      RUBY

      assert_match "true", rails("runner", "puts Rails.application.config.ran")
    end

    def test_default_environment
      assert_match "development", rails("runner", "puts Rails.env")
    end

    def test_runner_detects_syntax_errors
      output = rails("runner", "puts 'hello world", allow_failure: true)
      assert_not_predicate $?, :success?
      assert_match "unterminated string meets end of file", output
    end

    def test_runner_detects_bad_script_name
      output = rails("runner", "iuiqwiourowe", allow_failure: true)
      assert_not_predicate $?, :success?
      assert_match "undefined local variable or method `iuiqwiourowe' for", output
    end

    def test_environment_with_rails_env
      with_rails_env "production" do
        assert_match "production", rails("runner", "puts Rails.env")
      end
    end

    def test_environment_with_rack_env
      with_rack_env "production" do
        assert_match "production", rails("runner", "puts Rails.env")
      end
    end

    def test_can_call_same_name_class_as_defined_in_thor
      app_file "app/models/task.rb", <<-MODEL
      class Task
        def self.count
          42
        end
      end
      MODEL

      assert_match "42", rails("runner", "puts Task.count")
    end
  end
end

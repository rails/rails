require 'isolation/abstract_unit'

module ApplicationTests
  class RunnerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails

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

    def test_should_include_runner_in_shebang_line_in_help
      assert_match "/rails runner", Dir.chdir(app_path) { `bundle exec rails runner --help` }
    end

    def test_should_run_ruby_statement
      assert_match "42", Dir.chdir(app_path) { `bundle exec rails runner "puts User.count"` }
    end

    def test_should_run_file
      app_file "script/count_users.rb", <<-SCRIPT
      puts User.count
      SCRIPT

      assert_match "42", Dir.chdir(app_path) { `bundle exec rails runner "script/count_users.rb"` }
    end

    def test_should_set_dollar_0_to_file
      app_file "script/dollar0.rb", <<-SCRIPT
      puts $0
      SCRIPT

      assert_match "script/dollar0.rb", Dir.chdir(app_path) { `bundle exec rails runner "script/dollar0.rb"` }
    end

    def test_should_set_dollar_program_name_to_file
      app_file "script/program_name.rb", <<-SCRIPT
      puts $PROGRAM_NAME
      SCRIPT

      assert_match "script/program_name.rb", Dir.chdir(app_path) { `bundle exec rails runner "script/program_name.rb"` }
    end
  end
end

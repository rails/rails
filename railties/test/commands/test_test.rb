# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::TestTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "test command with no args runs test:prepare task" do
    assert_runs_prepare_task do
      run_test_command("test")
    end
  end

  test "test command with path arg skips test:prepare task" do
    app_file "test/some_test.rb", ""

    assert_skips_prepare_task do
      run_test_command("test", "test/some_test.rb")
    end

    assert_skips_prepare_task do
      run_test_command("test", "test/some_test")
    end

    assert_skips_prepare_task do
      run_test_command("test", "test/some_test.rb:1")
    end

    assert_skips_prepare_task do
      run_test_command("test", "./test/*_test.rb")
    end
  end

  test "test command with options runs test:prepare task" do
    assert_runs_prepare_task do
      run_test_command("test", "--seed", "1234", "-e", "development")
    end
  end

  test "test command with name option skips test:prepare task" do
    assert_skips_prepare_task do
      run_test_command("test", "-n", "test_some_code", allow_failure: true)
    end

    assert_skips_prepare_task do
      run_test_command("test", "-n", "/some_code/", allow_failure: true)
    end

    assert_skips_prepare_task do
      run_test_command("test", "-n", "some code", allow_failure: true)
    end

    assert_skips_prepare_task do
      run_test_command("test", "--name", "test_some_code", allow_failure: true)
    end

    assert_skips_prepare_task do
      run_test_command("test", "--name=test_some_code", allow_failure: true)
    end
  end

  test "test command runs successfully when no tasks defined" do
    app_file "Rakefile", ""
    assert_successful_run run_test_command("test")
  end

  test "test:all runs test:prepare task" do
    assert_runs_prepare_task do
      run_test_command("test:all")
    end
  end

  test "test:all with name option skips test:prepare task" do
    assert_skips_prepare_task do
      run_test_command("test:all", "-n", "test_some_code", allow_failure: true)
    end
  end

  test "test:* runs test:prepare task" do
    assert_runs_prepare_task do
      run_test_command("test:models")
    end
  end

  test "test:* with name option skips test:prepare task" do
    assert_skips_prepare_task do
      run_test_command("test:models", "-n", "test_some_code", allow_failure: true)
    end
  end

  private
    def run_test_command(subcommand = "test", *args, **options)
      rails subcommand, args, **options
    end

    def enhance_prepare_task_with_output(output)
      app_file "Rakefile", <<~RUBY, "a"
        task :enhancing do
          puts #{output.inspect}
        end
        Rake::Task["test:prepare"].enhance(["enhancing"])
      RUBY
    end

    def assert_successful_run(test_command_output)
      assert_match "0 failures, 0 errors", test_command_output
    end

    def assert_runs_prepare_task(&block)
      enhance_prepare_task_with_output("Prepare yourself!")
      output = block.call
      assert_successful_run output
      assert_match "Prepare yourself!", output
      output
    end

    def assert_skips_prepare_task(&block)
      enhance_prepare_task_with_output("Prepare yourself!")
      output = block.call
      assert_successful_run output
      assert_no_match "Prepare yourself!", output
      output
    end
end

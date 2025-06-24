# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::RunnerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  def test_rails_runner_with_stdin
    command_output = `echo "puts 'Hello world'" | #{app_path}/bin/rails runner -`

    assert_equal <<~OUTPUT, command_output
      Hello world
    OUTPUT
  end

  def test_rails_runner_with_file
    # We intentionally define a file with a name that matches the one of the
    # script that we want to run to ensure that runner executes the latter one.
    app_file "lib/foo.rb", "# Lib file"

    app_file "foo.rb", <<-RUBY
    puts "Hello world"
    RUBY

    assert_equal <<~OUTPUT, run_runner_command("foo.rb")
      Hello world
    OUTPUT
  end

  def test_rails_runner_with_file_path_that_does_not_exist
    command_output = run_runner_command("no-file-here.rb", allow_failure: true)

    assert_match(/The file no-file-here.rb could not be found/, command_output)
    assert_equal 1, $?.exitstatus
  end

  def test_rails_runner_with_ruby_code
    assert_equal <<~OUTPUT, run_runner_command('puts "Hello world"')
      Hello world
    OUTPUT
  end

  def test_rails_runner_with_conditional_executor
    assert_equal <<~OUTPUT, run_runner_command("puts Rails.application.executor.active?", allow_failure: true)
      true
    OUTPUT

    assert_equal <<~OUTPUT, run_runner_command("--skip-executor", "puts Rails.application.executor.active?", allow_failure: true)
      false
    OUTPUT
  end

  def test_rails_runner_with_syntax_error_in_ruby_code
    command_output = run_runner_command("This is not ruby code", allow_failure: true)

    assert_match(/Please specify a valid ruby command/, command_output)
    assert_equal 1, $?.exitstatus
  end

  def test_rails_runner_with_name_error_in_ruby_code
    assert_raise(NameError) { IDoNotExist }

    command_output = run_runner_command("IDoNotExist.new", allow_failure: true)

    assert_match(/Please specify a valid ruby command/, command_output)
    assert_equal 1, $?.exitstatus
  end

  private
    def run_runner_command(*arguments, allow_failure: false)
      rails "runner", *arguments, allow_failure: allow_failure
    end
end

# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::HelpIntegrationTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "when passing --trace it invokes default" do
    assert_match "Invoke default", rails("--trace")
  end

  test "prints helpful error on unrecognized command" do
    output = rails "vershen", allow_failure: true

    assert_match %(Unrecognized command "vershen"), output
    assert_match "Did you mean?  version", output
  end

  test "loads Rake tasks only once on unrecognized command" do
    app_file "lib/tasks/my_task.rake", <<~RUBY
      puts "MY_TASK already defined? => \#{!!defined?(MY_TASK)}"
      MY_TASK = true
    RUBY

    output = rails "vershen", allow_failure: true

    assert_match "MY_TASK already defined? => false", output
    assert_no_match "MY_TASK already defined? => true", output
  end

  test "prints help via `X:help` command when running `X` and `X:X` command is not defined" do
    help = rails "dev:help"
    output = rails "dev", allow_failure: true

    assert_match help, output
  end

  test "prints Rake tasks on --tasks / -T option" do
    app_file "lib/tasks/my_task.rake", <<~RUBY
      Rake.application.clear

      desc "my_task"
      task :my_task
    RUBY

    assert_match "my_task", rails("--tasks")
    assert_match "my_task", rails("-T")
  end

  test "excludes application Rake tasks from command list via --help" do
    app_file "Rakefile", <<~RUBY, "a"
      desc "my_task"
      task :my_task_1
    RUBY

    app_file "lib/tasks/my_task.rake", <<~RUBY
      desc "my_task"
      task :my_task_2
    RUBY

    assert_no_match "my_task", rails("--help")
  end
end

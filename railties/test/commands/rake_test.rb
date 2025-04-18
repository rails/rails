# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::RakeTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "runs multiple tasks" do
    app_file "lib/tasks/foo.rake", 'task(:foo) { puts "FOO!" }'
    app_file "lib/tasks/bar.rake", 'task(:bar) { puts "BAR!" }'

    output = run_rake_command "foo", "bar"
    assert_match "FOO!", output
    assert_match "BAR!", output
  end

  test "runs task with arguments" do
    app_file "lib/tasks/hello.rake", <<~RUBY
      namespace :greetings do
        task :hello, [:name] do |task, args|
          puts "Hello, \#{args.name}!"
        end
      end
    RUBY

    assert_match "Hello, World!", run_rake_command("greetings:hello[World]")
  end

  private
    def run_rake_command(*args, **options)
      rails args, **options
    end
end

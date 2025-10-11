# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/rake/rake_command"

class Rails::Command::RakeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

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

  test "error report and re-raises when task raises" do
    app_file "lib/tasks/exception.rake", 'task(:exception) { raise StandardError, "rake error" }'
    app_file "config/initializers/error_subscriber.rb", <<-RUBY
      class ErrorSubscriber
        def report(error, handled:, severity:, context:, source: nil)
          Rails.logger.error(source)
        end
      end

      Rails.application.config.after_initialize do
        Rails.error.subscribe(ErrorSubscriber.new)
      end
    RUBY
    Rails.env = "test"
    require "#{app_path}/config/environment"
    assert_raises(StandardError) { run_rake_command("exception") }

    logs = File.read("#{app_path}/log/test.log")
    assert_match("rake_command.rails\n", logs)
  end

  private
    def run_rake_command(*args, **options)
      rails args, **options
    end
end

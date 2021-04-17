# frozen_string_literal: true

gem "minitest"
require "minitest"
require "rails/test_unit/runner"

task default: :test

desc "Runs all tests in test folder except system ones"
task :test do
  if ENV.key?("TEST")
    Rails::TestUnit::Runner.rake_run([ENV["TEST"]])
  else
    Rails::TestUnit::Runner.rake_run
  end
end

namespace :test do
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance.
    # If used with Active Record, this task runs before the database schema is synchronized.
  end

  task run: %w[test]

  desc "Run tests quickly, but also reset db"
  task :db do
    success = system({ "RAILS_ENV" => ENV.fetch("RAILS_ENV", "test") }, "rake", "db:test:prepare", "test")
    success || exit(false)
  end

  def test_paths(paths)
    Rails::TestUnit::Runner.rake_run([*paths, *ARGV])
  end

  ["models", "helpers", "channels", "controllers", "mailers", "integration", "jobs", "mailboxes"].each do |name|
    task name => "test:prepare" do
      test_paths(["test/#{name}"])
    end
  end

  desc "Runs all tests, including system tests"
  task all: "test:prepare" do
    test_paths(["test/**/*_test.rb"])
  end

  task generators: "test:prepare" do
    test_paths(["test/lib/generators"])
  end

  task units: "test:prepare" do
    test_paths(["test/models", "test/helpers", "test/unit"])
  end

  task functionals: "test:prepare" do
    test_paths(["test/controllers", "test/mailers", "test/functional"])
  end

  desc "Run system tests only"
  task system: "test:prepare" do
    test_paths(["test/system"])
  end
end

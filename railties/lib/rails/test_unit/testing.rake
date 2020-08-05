# frozen_string_literal: true

gem "minitest"
require "minitest"
require "rails/test_unit/runner"

task default: :test

desc "Runs all tests in test folder except system ones"
task :test do
  $: << "test"

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
  task db: %w[db:test:prepare test]

  ["models", "helpers", "channels", "controllers", "mailers", "integration", "jobs", "mailboxes"].each do |name|
    task name => "test:prepare" do
      $: << "test"
      Rails::TestUnit::Runner.rake_run(["test/#{name}"])
    end
  end

  desc "Runs all tests, including system tests"
  task all: "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/**/*_test.rb"])
  end

  task generators: "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/lib/generators"])
  end

  task units: "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/models", "test/helpers", "test/unit"])
  end

  task functionals: "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/controllers", "test/mailers", "test/functional"])
  end

  desc "Run system tests only"
  task system: "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/system"])
  end
end

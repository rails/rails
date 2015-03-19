require "rails/test_unit/runner"

task default: :test

desc "Runs all tests in test folder"
task :test do
  $: << "test"
  ARGV.shift if ARGV[0] == "test"
  Rails::TestRunner.run(ARGV)
end

namespace :test do
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance.
    # If used with Active Record, this task runs before the database schema is synchronized.
  end

  task :run => %w[test]

  desc "Run tests quickly, but also reset db"
  task :db => %w[db:test:prepare test]

  ["models", "helpers", "controllers", "mailers", "integration", "jobs"].each do |name|
    task name => "test:prepare" do
      $: << "test"
      Rails::TestRunner.run(["test/#{name}"])
    end
  end

  task :generators => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/lib/generators"])
  end

  task :units => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/models", "test/helpers", "test/unit"])
  end

  task :functionals => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/controllers", "test/mailers", "test/functional"])
  end
end

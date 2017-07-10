gem "minitest"
require "minitest"
require_relative "runner"

task default: :test

desc "Runs all tests in test folder"
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

  task :run => %w[test]

  desc "Run tests quickly, but also reset db"
  task :db => %w[db:test:prepare test]

  ["models", "helpers", "controllers", "mailers", "integration", "jobs"].each do |name|
    task name => "test:prepare" do
      $: << "test"
      Rails::TestUnit::Runner.rake_run(["test/#{name}"])
    end
  end

  task :generators => "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/lib/generators"])
  end

  task :units => "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/models", "test/helpers", "test/unit"])
  end

  task :functionals => "test:prepare" do
    $: << "test"
    Rails::TestUnit::Runner.rake_run(["test/controllers", "test/mailers", "test/functional"])
  end
end

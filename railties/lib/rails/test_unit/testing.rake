require "rails/test_unit/runner"

task default: :test

desc "Runs all tests in test folder"
task :test do
  $: << "test"
  args = ARGV[0] == "test" ? ARGV[1..-1] : []
  Rails::TestRunner.run(args)
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
    desc "Runs all the #{name.singularize} tests from test/#{name}"
    task name => "test:prepare" do
      $: << "test"
      Rails::TestRunner.run(["test/#{name}"])
    end
  end

  desc "Runs all the generator tests from test/lib/generators"
  task :generators => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/lib/generators"])
  end

  desc "Runs all the unit tests from test/models, test/helpers, and test/unit"
  task :units => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/models", "test/helpers", "test/unit"])
  end

  desc "Runs all the functional tests from test/controllers, test/mailers, and test/functional"
  task :functionals => "test:prepare" do
    $: << "test"
    Rails::TestRunner.run(["test/controllers", "test/mailers", "test/functional"])
  end
end

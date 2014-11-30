require 'rake/testtask'
require 'rails/test_unit/sub_test_task'

task default: :test

desc "Runs all tests in test folder"
task :test do
  Rails::TestTask.test_creator(Rake.application.top_level_tasks).invoke_rake_task
end

namespace :test do
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance.
    # If used with Active Record, this task runs before the database schema is synchronized.
  end

  Rails::TestTask.new(:run) do |t|
    t.pattern = "test/**/*_test.rb"
  end

  desc "Run tests quickly, but also reset db"
  task :db => %w[db:test:prepare test]

  desc "Run tests quickly by merging all types and not resetting db"
  Rails::TestTask.new(:all) do |t|
    t.pattern = "test/**/*_test.rb"
  end

  Rake::Task["test:all"].enhance do
    Rake::Task["test:deprecate_all"].invoke
  end

  task :deprecate_all do
    ActiveSupport::Deprecation.warn "rake test:all is deprecated and will be removed in Rails 5. " \
    "Use rake test to run all tests in test directory."
  end

  namespace :all do
    desc "Run tests quickly, but also reset db"
    task :db => %w[db:test:prepare test:all]

    Rake::Task["test:all:db"].enhance do
      Rake::Task["test:deprecate_all"].invoke
    end
  end

  Rails::TestTask.new(single: "test:prepare")

  ["models", "helpers", "controllers", "mailers", "integration", "jobs"].each do |name|
    Rails::TestTask.new(name => "test:prepare") do |t|
      t.pattern = "test/#{name}/**/*_test.rb"
    end
  end

  Rails::TestTask.new(generators: "test:prepare") do |t|
    t.pattern = "test/lib/generators/**/*_test.rb"
  end

  Rails::TestTask.new(units: "test:prepare") do |t|
    t.pattern = 'test/{models,helpers,unit}/**/*_test.rb'
  end

  Rails::TestTask.new(functionals: "test:prepare") do |t|
    t.pattern = 'test/{controllers,mailers,functional}/**/*_test.rb'
  end
end

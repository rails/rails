require 'rbconfig'
require 'rake/testtask'
require 'rails/test_unit/sub_test_task'
require 'active_support/deprecation'

task default: :test

desc 'Runs test:units, test:functionals, test:integration together'
task :test do
  info = Rails::TestTask.test_info Rake.application.top_level_tasks
  if info.files.any?
    Rails::TestTask.new('test:single') { |t|
      t.test_files = info.files
    }
    ENV['TESTOPTS'] ||= info.opts
    Rake.application.top_level_tasks.replace info.tasks

    Rake::Task['test:single'].invoke
  else
    Rake::Task[ENV['TEST'] ? 'test:single' : 'test:run'].invoke
  end
end

namespace :test do
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance. See Active Record for an example.
  end

  task :run => ['test:units', 'test:functionals', 'test:integration']

  # Inspired by: http://ngauthier.com/2012/02/quick-tests-with-bash.html
  desc "Run tests quickly by merging all types and not resetting db"
  Rails::TestTask.new(:all) do |t|
    t.pattern = "test/**/*_test.rb"
  end

  namespace :all do
    desc "Run tests quickly, but also reset db"
    task :db => %w[db:test:prepare test:all]
  end

  Rails::TestTask.new(single: "test:prepare")

  ["models", "helpers", "controllers", "mailers", "integration"].each do |name|
    Rails::TestTask.new(name => "test:prepare") do |t|
      t.pattern = "test/#{name}/**/*_test.rb"
    end
  end

  Rails::TestTask.new(units: "test:prepare") do |t|
    t.pattern = 'test/{models,helpers,unit}/**/*_test.rb'
  end

  Rails::TestTask.new(functionals: "test:prepare") do |t|
    t.pattern = 'test/{controllers,mailers,functional}/**/*_test.rb'
  end
end

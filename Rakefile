# frozen_string_literal: true

require "net/http"

$:.unshift __dir__
require "tasks/release"
require "railties/lib/rails/api/task"
require "tools/preview_docs"

desc "Run all tests by default"
task default: %w(test test:isolated)

%w(test test:isolated).each do |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name do
    errors = []
    Releaser::FRAMEWORKS.each do |project|
      system(%(cd #{project} && #{$0} #{task_name} --trace)) || errors << project
    end
    fail("Errors in #{errors.join(', ')}") unless errors.empty?
  end
end

Releaser::FRAMEWORKS.each do |framework|
  namespace framework do
    desc "Run tests for #{framework}"
    task :test do
      ok = system(%(cd #{framework} && #{$0} test --trace))
      fail("Errors in #{framework}") unless ok
    end

    desc "Run isolated tests for #{framework}"
    task :isolated do
      # Active Storage doesn't define a test:isolated task; explicitly fail
      if framework == "activestorage"
        abort "activestorage:isolated is not supported"
      else
        ok = system(%(cd #{framework} && #{$0} test:isolated --trace))
        fail("Errors in #{framework}") unless ok
      end
    end
  end
end

namespace :activejob do
  activejob_adapters = %w(async inline queue_classic resque sidekiq sneakers backburner test)
  activejob_adapters.delete("queue_classic") if defined?(JRUBY_VERSION)

  desc "Run Active Job integration tests for all adapters"
  task :integration do
    ok = system(%(cd activejob && #{$0} test:integration --trace))
    fail("Errors in activejob integration") unless ok
  end

  activejob_adapters.each do |adapter|
    namespace adapter do
      desc "Run tests for activejob #{adapter} adapter"
      task :test do
        ok = system(%(cd activejob && #{$0} test:#{adapter} --trace))
        fail("Errors in activejob:#{adapter}") unless ok
      end

      desc "Run isolated tests for activejob #{adapter} adapter"
      task :isolated do
        ok = system(%(cd activejob && #{$0} test:isolated:#{adapter} --trace))
        fail("Errors in activejob:#{adapter}") unless ok
      end

      desc "Run Active Job #{adapter} adapter integration tests"
      task :integration do
        ok = system(%(cd activejob && #{$0} test:integration:#{adapter} --trace))
        fail("Errors in activejob:#{adapter} integration") unless ok
      end
    end
  end
end

namespace :activerecord do
  %w(mysql2 trilogy postgresql sqlite3 sqlite3_mem).each do |adapter|
    namespace adapter do
      desc "Run Active Record #{adapter} adapter tests"
      task :test do
        ok = system(%(cd activerecord && #{$0} test:#{adapter} --trace))
        fail("Errors in activerecord:#{adapter}") unless ok
      end

      desc "Run Active Record #{adapter} adapter isolated tests"
      task :isolated do
        ok = system(%(cd activerecord && #{$0} test:isolated:#{adapter} --trace))
        fail("Errors in activerecord:#{adapter} isolated") unless ok
      end

      desc "Run Active Record #{adapter} adapter integration tests"
      task :integration do
        ok = system(%(cd activerecord && #{$0} test:integration:active_job:#{adapter} --trace))
        fail("Errors in activerecord:#{adapter} integration") unless ok
      end
    end
  end

  desc "Run Active Record integration tests for all adapters"
  task :integration do
    ok = system(%(cd activerecord && #{$0} test:integration:active_job --trace))
    fail("Errors in activerecord integration") unless ok
  end

  namespace :db do
    desc "Build MySQL and PostgreSQL test databases"
    task :create do
      ok = system(%(cd activerecord && #{$0} db:create --trace))
      fail("Errors in activerecord db:create") unless ok
    end

    desc "Drop MySQL and PostgreSQL test databases"
    task :drop do
      ok = system(%(cd activerecord && #{$0} db:drop --trace))
      fail("Errors in activerecord db:drop") unless ok
    end

    desc "Rebuild MySQL and PostgreSQL test databases"
    task :rebuild do
      ok = system(%(cd activerecord && #{$0} db:mysql:rebuild --trace))
      ok &&= system(%(cd activerecord && #{$0} db:postgresql:rebuild --trace))
      fail("Errors in activerecord db:rebuild") unless ok
    end

    namespace :mysql do
      desc "Build Active Record MySQL test databases"
      task :build do
        ok = system(%(cd activerecord && #{$0} db:mysql:build --trace))
        fail("Errors in activerecord db:mysql:build") unless ok
      end

      desc "Drop Active Record MySQL test databases"
      task :drop do
        ok = system(%(cd activerecord && #{$0} db:mysql:drop --trace))
        fail("Errors in activerecord db:mysql:drop") unless ok
      end

      desc "Rebuild Active Record MySQL test databases"
      task :rebuild do
        ok = system(%(cd activerecord && #{$0} db:mysql:rebuild --trace))
        fail("Errors in activerecord db:mysql:rebuild") unless ok
      end
    end

    namespace :postgresql do
      desc "Build Active Record PostgreSQL test databases"
      task :build do
        ok = system(%(cd activerecord && #{$0} db:postgresql:build --trace))
        fail("Errors in activerecord db:postgresql:build") unless ok
      end

      desc "Drop Active Record PostgreSQL test databases"
      task :drop do
        ok = system(%(cd activerecord && #{$0} db:postgresql:drop --trace))
        fail("Errors in activerecord db:postgresql:drop") unless ok
      end

      desc "Rebuild Active Record PostgreSQL test databases"
      task :rebuild do
        ok = system(%(cd activerecord && #{$0} db:postgresql:rebuild --trace))
        fail("Errors in activerecord db:postgresql:rebuild") unless ok
      end
    end
  end
end

desc "Smoke-test all projects"
task :smoke, [:frameworks, :isolated] do |task, args|
  frameworks = args[:frameworks] ? args[:frameworks].split(" ") : Releaser::FRAMEWORKS
  # The arguments are positional, and users may want to specify only the isolated flag.. so we allow 'all' as a default for the first argument:
  if frameworks.include?("all")
    frameworks = Releaser::FRAMEWORKS
  end

  isolated = args[:isolated].nil? || args[:isolated] == "true"
  test_task = isolated ? "test:isolated" : "test"

  (frameworks - ["activerecord"]).each do |project|
    system %(cd #{project} && #{$0} #{test_task} --trace)
  end

  if frameworks.include? "activerecord"
    test_task = isolated ? "sqlite3:isolated_test" : "sqlite3:test"
    system %(cd activerecord && #{$0} #{test_task} --trace)
  end
end

desc "Generate documentation for the Rails framework"
if ENV["EDGE"]
  Rails::API::EdgeTask.new("rdoc")
else
  Rails::API::StableTask.new("rdoc")
end

desc "Generate documentation for previewing"
task :preview_docs do
  FileUtils.mkdir_p("preview")
  PreviewDocs.new.render("preview")

  require "guides/rails_guides"
  Rake::Task[:rdoc].invoke

  FileUtils.mv("doc/rdoc", "preview/api")
  FileUtils.mv("guides/output", "preview/guides")

  system("tar -czf preview.tar.gz -C preview .")
end

# We have a webhook configured in GitHub that gets invoked after pushes.
# This hook triggers the following tasks:
#
#   * updates the local checkout
#   * updates Rails Contributors
#   * generates and publishes edge docs
#   * if there's a new stable tag, generates and publishes stable docs
#
# Everything is automated and you do NOT need to run this task normally.
desc "Publishes docs, run this AFTER a new stable tag has been pushed"
task :publish_docs do
  Net::HTTP.new("api.rubyonrails.org", 8080).start do |http|
    request  = Net::HTTP::Post.new("/rails-master-hook")
    response = http.request(request)
    puts response.body
  end
end

# frozen_string_literal: true

require "net/http"

$:.unshift __dir__
require "tasks/release"
require "railties/lib/rails/api/task"
require "tools/preview_docs"

desc "Build gem files for all projects"
task build: "all:build"

desc "Build, install and verify the gem files in a generated Rails app."
task verify: "all:verify"

desc "Prepare the release"
task prep_release: "all:prep_release"

desc "Release all gems to rubygems and create a tag"
task release: "all:release"

desc "Run all tests by default"
task default: %w(test test:isolated)

%w(test test:isolated package gem).each do |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name do
    errors = []
    FRAMEWORKS.each do |project|
      system(%(cd #{project} && #{$0} #{task_name} --trace)) || errors << project
    end
    fail("Errors in #{errors.join(', ')}") unless errors.empty?
  end
end

desc "Smoke-test all projects"
task :smoke do
  (FRAMEWORKS - %w(activerecord)).each do |project|
    system %(cd #{project} && #{$0} test:isolated --trace)
  end
  system %(cd activerecord && #{$0} sqlite3:isolated_test --trace)
end

desc "Install gems for all projects."
task install: "all:install"

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

  Dir.chdir("preview") do
    system("tar -czf preview.tar.gz .")
  end
end

desc "Bump all versions to match RAILS_VERSION"
task update_versions: "all:update_versions"

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

# frozen_string_literal: true

require "net/http"

$:.unshift __dir__
require "tasks/release"
require "railties/lib/rails/api/task"

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

desc "Smoke-test all projects"
task :smoke, [:frameworks, :isolated] do |task, args|
  frameworks = args[:frameworks] ? args[:frameworks].split(" ") : Releaser::FRAMEWORKS
  # The arguments are positional, and users may want to specify only the isolated flag.. so we allow 'all' as a default for the first argument:
  if frameworks.include?("all")
    frameworks = Releaser::FRAMEWORKS
  end

  isolated = args[:isolated].nil? ? true : args[:isolated] == "true"
  test_task = isolated ? "test:isolated" : "test"

  (frameworks - ["activerecord"]).each do |project|
    system %(cd #{project} && #{$0} #{test_task} --trace)
  end
  system %(cd activerecord && #{$0} sqlite3:isolated_test --trace)
end

desc "Generate documentation for the Rails framework"
if ENV["EDGE"]
  Rails::API::EdgeTask.new("rdoc")
else
  Rails::API::StableTask.new("rdoc")
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

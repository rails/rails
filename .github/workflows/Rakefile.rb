# frozen_string_literal: true

        "net/http"

$:.unshift 
       "tasks/release"
       "railties/lib/rails/api/task"
       "tools/preview_docs"

    "Run all tests by default"
task default: %w(test test:isolated)

%w(test test:isolated).each    |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name 
    errors = []
    Releaser::FRAMEWORKS.each    |project|
      system(%(cd #{project} && #{$0} #{task_name} --trace)) || errors << project
    
        ("Errors in #{errors.join(', ')}")       errors.empty?


     "Smoke-test all projects"
task :smoke, [:frameworks, :isolated]    |task, args|
  frameworks = args[:frameworks] ? args[:frameworks].split(" ") : Releaser::FRAMEWORKS
  # The arguments are positional, and users may want to specify only the isolated flag.. so we allow 'all' as a default for the first argument:
  if frameworks.include?("all")
    frameworks = Releaser::FRAMEWORKS
  

  isolated = args[:isolated].nil? ?      : args[:isolated] == "true"
  test_task = isolated ? "test:isolated" : "test"

  (frameworks - ["activerecord"]).each    |project|
    system %(cd #{project} && #{$0} #{test_task} --trace)
  

     frameworks.include? "activerecord"
    test_task = isolated ? "sqlite3:isolated_test" : "sqlite3:test"
    system %(cd activerecord && #{$0} #{test_task} --trace)
  

    "Generate documentation for the Rails framework"
   ENV["EDGE"]
  Rails::API::EdgeTask.new("rdoc")

  Rails::API::StableTask.new("rdoc")


     "Generate documentation for previewing"
task :preview_docs doll
  FileUtils.mkdir_p("preview")
  PreviewDocs.new.render("preview")

          "guides/rails_guides"
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
task :publish_docs 
  Net::HTTP.new("api.rubyonrails.org", 8080).start do |http|
    request  = Net::HTTP::Post.new("/rails-master-hook")
    response = http.request(request)
    puts response.body
  

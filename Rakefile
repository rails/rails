require 'rdoc/task'
require 'sdoc'
require 'net/http'

$:.unshift File.expand_path('..', __FILE__)
require "tasks/release"

desc "Build gem files for all projects"
task :build => "all:build"

desc "Release all gems to gemcutter and create a tag"
task :release => "all:release"

PROJECTS = %w(activesupport activemodel actionpack actionmailer activerecord railties)

desc 'Run all tests by default'
task :default => %w(test test:isolated)

%w(test test:isolated package gem).each do |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name do
    errors = []
    PROJECTS.each do |project|
      system(%(cd #{project} && #{$0} #{task_name})) || errors << project
    end
    fail("Errors in #{errors.join(', ')}") unless errors.empty?
  end
end

desc "Smoke-test all projects"
task :smoke do
  (PROJECTS - %w(activerecord)).each do |project|
    system %(cd #{project} && #{$0} test:isolated)
  end
  system %(cd activerecord && #{$0} sqlite3:isolated_test)
end

desc "Install gems for all projects."
task :install => :gem do
  version = File.read("RAILS_VERSION").strip
  (PROJECTS - ["railties"]).each do |project|
    puts "INSTALLING #{project}"
    system("gem install #{project}/pkg/#{project}-#{version}.gem --local --no-ri --no-rdoc")
  end
  system("gem install railties/pkg/railties-#{version}.gem --local --no-ri --no-rdoc")
  system("gem install pkg/rails-#{version}.gem --local --no-ri --no-rdoc")
end

desc "Generate documentation for the Rails framework"
RDoc::Task.new do |rdoc|
  RDOC_MAIN = 'RDOC_MAIN.rdoc'

  # This is a hack.
  #
  # Backslashes are needed to prevent RDoc from autolinking "Rails" to the
  # documentation of the Rails module. On the other hand, as of this
  # writing README.rdoc is displayed in the front page of the project in
  # GitHub, where backslashes are shown and look weird.
  #
  # The temporary solution is to have a README.rdoc without backslashes for
  # GitHub, and gsub it to generate the main page of the API.
  #
  # Also, relative links in GitHub have to point to blobs, whereas in the API
  # they need to point to files.
  #
  # The idea for the future is to have totally different files, since the
  # API is no longer a generic entry point to Rails and deserves a
  # dedicated main page specifically thought as an API entry point.
  rdoc.before_running_rdoc do
    rdoc_main = File.read('README.rdoc')

    # The ^(?=\S) assertion prevents code blocks from being processed,
    # since no autolinking happens there and RDoc displays the backslash
    # otherwise.
    rdoc_main.gsub!(/^(?=\S).*?\b(?=Rails)\b/) { "#$&\\" }
    rdoc_main.gsub!(%r{link:/rails/rails/blob/master/(\w+)/README\.rdoc}, "link:files/\\1/README_rdoc.html")

    # Remove Travis and Gemnasium status images from API pages. Only the GitHub
    # README page gets these images. Travis's HTTPS build image is used to
    # avoid GitHub caching: http://about.travis-ci.org/docs/user/status-images
    rdoc_main.gsub!(/^== Code Status(\n(?!==).*)*/, '')

    File.open(RDOC_MAIN, 'w') do |f|
      f.write(rdoc_main)
    end

    rdoc.rdoc_files.include(RDOC_MAIN)
  end

  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "Ruby on Rails Documentation"

  rdoc.options << '-f' << 'sdoc'
  rdoc.options << '-T' << 'rails'
  rdoc.options << '-e' << 'UTF-8'
  rdoc.options << '-g' # SDoc flag, link methods to GitHub
  rdoc.options << '-m' << RDOC_MAIN

  rdoc.rdoc_files.include('railties/CHANGELOG.md')
  rdoc.rdoc_files.include('railties/MIT-LICENSE')
  rdoc.rdoc_files.include('railties/README.rdoc')
  rdoc.rdoc_files.include('railties/lib/**/*.rb')
  rdoc.rdoc_files.exclude('railties/lib/rails/generators/**/templates/**/*.rb')

  rdoc.rdoc_files.include('activerecord/README.rdoc')
  rdoc.rdoc_files.include('activerecord/CHANGELOG.md')
  rdoc.rdoc_files.include('activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('activerecord/lib/active_record/vendor/*')

  rdoc.rdoc_files.include('actionpack/README.rdoc')
  rdoc.rdoc_files.include('actionpack/CHANGELOG.md')
  rdoc.rdoc_files.include('actionpack/lib/abstract_controller/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_dispatch/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_view/**/*.rb')
  rdoc.rdoc_files.exclude('actionpack/lib/action_controller/vendor/*')

  rdoc.rdoc_files.include('actionmailer/README.rdoc')
  rdoc.rdoc_files.include('actionmailer/CHANGELOG.md')
  rdoc.rdoc_files.include('actionmailer/lib/action_mailer/**/*.rb')
  rdoc.rdoc_files.exclude('actionmailer/lib/action_mailer/vendor/*')

  rdoc.rdoc_files.include('activesupport/README.rdoc')
  rdoc.rdoc_files.include('activesupport/CHANGELOG.md')
  rdoc.rdoc_files.include('activesupport/lib/active_support/**/*.rb')
  rdoc.rdoc_files.exclude('activesupport/lib/active_support/vendor/*')

  rdoc.rdoc_files.include('activemodel/README.rdoc')
  rdoc.rdoc_files.include('activemodel/CHANGELOG.md')
  rdoc.rdoc_files.include('activemodel/lib/active_model/**/*.rb')
end

# Enhance rdoc task to copy referenced images also
task :rdoc do
  FileUtils.mkdir_p "doc/rdoc/files/examples/"
  FileUtils.copy "activerecord/examples/associations.png", "doc/rdoc/files/examples/associations.png"
end

desc 'Bump all versions to match version.rb'
task :update_versions do
  require File.dirname(__FILE__) + "/version"

  File.open("RAILS_VERSION", "w") do |f|
    f.write Rails::VERSION::STRING + "\n"
  end

  constants = {
    "activesupport"   => "ActiveSupport",
    "activemodel"     => "ActiveModel",
    "actionpack"      => "ActionPack",
    "actionmailer"    => "ActionMailer",
    "activerecord"    => "ActiveRecord",
    "railties"        => "Rails"
  }

  version_file = File.read("version.rb")

  PROJECTS.each do |project|
    Dir["#{project}/lib/*/version.rb"].each do |file|
      File.open(file, "w") do |f|
        f.write version_file.gsub(/Rails/, constants[project])
      end
    end
  end
end

#
# We have a webhook configured in Github that gets invoked after pushes.
# This hook triggers the following tasks:
#
#   * updates the local checkout
#   * updates Rails Contributors
#   * generates and publishes edge docs
#   * if there's a new stable tag, generates and publishes stable docs
#
# Everything is automated and you do NOT need to run this task normally.
#
# We publish a new version by tagging, and pushing a tag does not trigger
# that webhook. Stable docs would be updated by any subsequent regular
# push, but if you want that to happen right away just run this.
#
desc 'Publishes docs, run this AFTER a new stable tag has been pushed'
task :publish_docs do
  Net::HTTP.new('api.rubyonrails.org', 8080).start do |http|
    request  = Net::HTTP::Post.new('/rails-master-hook')
    response = http.request(request)
    puts response.body
  end
end

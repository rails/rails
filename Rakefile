gem 'rdoc', '>= 2.5.10'
require 'rdoc'

require 'rake'
require 'rdoc/task'

$:.unshift File.expand_path('..', __FILE__)
require "tasks/release"

desc "Build gem files for all projects"
task :build => "all:build"

desc "Release all gems to gemcutter and create a tag"
task :release => "all:release"

# RDoc skips some files in the Rails tree due to its binary? predicate. This is a quick
# hack for edge docs, until we decide which is the correct way to address this issue.
# If not fixed in RDoc itself, via an option or something, we should probably move this
# to railties and use it also in doc:rails.
def hijack_rdoc!
  require "rdoc/parser"
  class << RDoc::Parser
    def binary?(file)
      s = File.read(file, 1024) or return false

      if s[0, 2] == Marshal.dump('')[0, 2] then
        true
      elsif file =~ /erb\.rb$/ then
        false
      elsif s.index("\x00") then # ORIGINAL is s.scan(/<%|%>/).length >= 4 || s.index("\x00")
        true
      elsif 0.respond_to? :fdiv then
        s.count("^ -~\t\r\n").fdiv(s.size) > 0.3
      else # HACK 1.8.6
        (s.count("^ -~\t\r\n").to_f / s.size) > 0.3
      end
    end
  end
end

PROJECTS = %w(activesupport activemodel actionpack actionmailer activeresource activerecord railties)

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
    system("gem install #{project}/pkg/#{project}-#{version}.gem --no-ri --no-rdoc")
  end
  system("gem install railties/pkg/railties-#{version}.gem --no-ri --no-rdoc")
  system("gem install pkg/rails-#{version}.gem --no-ri --no-rdoc")
end

desc "Generate documentation for the Rails framework"
RDoc::Task.new do |rdoc|
  hijack_rdoc!

  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "Ruby on Rails Documentation"

  rdoc.options << '-f' << 'horo'
  rdoc.options << '-c' << 'utf-8'
  rdoc.options << '-m' << 'README.rdoc'

  rdoc.rdoc_files.include('README.rdoc')

  rdoc.rdoc_files.include('railties/CHANGELOG')
  rdoc.rdoc_files.include('railties/MIT-LICENSE')
  rdoc.rdoc_files.include('railties/README.rdoc')
  rdoc.rdoc_files.include('railties/lib/**/*.rb')
  rdoc.rdoc_files.exclude('railties/lib/rails/generators/**/templates/*')

  rdoc.rdoc_files.include('activerecord/README.rdoc')
  rdoc.rdoc_files.include('activerecord/CHANGELOG')
  rdoc.rdoc_files.include('activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('activerecord/lib/active_record/vendor/*')

  rdoc.rdoc_files.include('activeresource/README.rdoc')
  rdoc.rdoc_files.include('activeresource/CHANGELOG')
  rdoc.rdoc_files.include('activeresource/lib/active_resource.rb')
  rdoc.rdoc_files.include('activeresource/lib/active_resource/*')

  rdoc.rdoc_files.include('actionpack/README.rdoc')
  rdoc.rdoc_files.include('actionpack/CHANGELOG')
  rdoc.rdoc_files.include('actionpack/lib/abstract_controller/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_dispatch/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_view/**/*.rb')
  rdoc.rdoc_files.exclude('actionpack/lib/action_controller/vendor/*')

  rdoc.rdoc_files.include('actionmailer/README.rdoc')
  rdoc.rdoc_files.include('actionmailer/CHANGELOG')
  rdoc.rdoc_files.include('actionmailer/lib/action_mailer/base.rb')
  rdoc.rdoc_files.exclude('actionmailer/lib/action_mailer/vendor/*')

  rdoc.rdoc_files.include('activesupport/README.rdoc')
  rdoc.rdoc_files.include('activesupport/CHANGELOG')
  rdoc.rdoc_files.include('activesupport/lib/active_support/**/*.rb')
  rdoc.rdoc_files.exclude('activesupport/lib/active_support/vendor/*')

  rdoc.rdoc_files.include('activemodel/README.rdoc')
  rdoc.rdoc_files.include('activemodel/CHANGELOG')
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
    "activeresource"  => "ActiveResource",
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

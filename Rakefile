gem 'rdoc', '= 2.2'
require 'rdoc'

require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'

PROJECTS = %w(activesupport activemodel actionpack actionmailer activeresource activerecord railties)

desc 'Run all tests by default'
task :default => %w(test test:isolated)

%w(test test:isolated rdoc package gem).each do |task_name|
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

spec = eval(File.read('rails.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Release all gems to gemcutter. Package rails, package & push components, then push rails"
task :release => :release_projects do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

desc "Release all components to gemcutter."
task :release_projects => :package do
  errors = []
  PROJECTS.each do |project|
    system(%(cd #{project} && #{$0} release)) || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
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
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "Ruby on Rails Documentation"

  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.options << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.options << '--main' << 'README.rdoc'

  # Workaround: RDoc assumes that rdoc.template can be required, and that
  # rdoc.template.upcase is a constant living in RDoc::Generator::HTML
  # which holds the actual template class.
  # 
  # We put 'doc/template' in the load path to be able to set the template
  # to the string 'horo' and thus meet those RDoc's assumptions.
  $:.unshift('doc/template')

  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : 'horo'

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

desc "Publish API docs for Rails as a whole and for each component"
task :pdoc => :rdoc do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("rails@api.rubyonrails.org", "public_html/api", "doc/rdoc").upload
  PROJECTS.each do |project|
    system %(cd #{project} && #{$0} pdoc)
  end
end

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

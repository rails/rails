require 'rake'
require 'rake/rdoctask'

env = %(PKG_BUILD="#{ENV['PKG_BUILD']}") if ENV['PKG_BUILD']

PROJECTS = %w(activesupport railties actionpack actionmailer activeresource activerecord)

Dir["#{File.dirname(__FILE__)}/*/lib/*/version.rb"].each do |version_path|
  require version_path
end

desc 'Run all tests by default'
task :default => :test

%w(test rdoc pgem package release).each do |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name do
    PROJECTS.each do |project|
      system %(cd #{project} && #{env} #{$0} #{task_name})
    end
  end
end


desc "Generate documentation for the Rails framework"
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "Ruby on Rails Documentation"

  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.options << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'

  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : './doc/template/horo'

  rdoc.rdoc_files.include('railties/CHANGELOG')
  rdoc.rdoc_files.include('railties/MIT-LICENSE')
  rdoc.rdoc_files.include('railties/README')
  rdoc.rdoc_files.include('railties/lib/{*.rb,commands/*.rb,rails/*.rb,rails_generator/*.rb}')

  rdoc.rdoc_files.include('activerecord/README')
  rdoc.rdoc_files.include('activerecord/CHANGELOG')
  rdoc.rdoc_files.include('activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('activerecord/lib/active_record/vendor/*')

  rdoc.rdoc_files.include('activeresource/README')
  rdoc.rdoc_files.include('activeresource/CHANGELOG')
  rdoc.rdoc_files.include('activeresource/lib/active_resource.rb')
  rdoc.rdoc_files.include('activeresource/lib/active_resource/*')

  rdoc.rdoc_files.include('actionpack/README')
  rdoc.rdoc_files.include('actionpack/CHANGELOG')
  rdoc.rdoc_files.include('actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('actionpack/lib/action_view/**/*.rb')
  rdoc.rdoc_files.exclude('actionpack/lib/action_controller/vendor/*')

  rdoc.rdoc_files.include('actionmailer/README')
  rdoc.rdoc_files.include('actionmailer/CHANGELOG')
  rdoc.rdoc_files.include('actionmailer/lib/action_mailer/base.rb')
  rdoc.rdoc_files.exclude('actionmailer/lib/action_mailer/vendor/*')

  rdoc.rdoc_files.include('activesupport/README')
  rdoc.rdoc_files.include('activesupport/CHANGELOG')
  rdoc.rdoc_files.include('activesupport/lib/active_support/**/*.rb')
  rdoc.rdoc_files.exclude('activesupport/lib/active_support/vendor/*')
end

# Enhance rdoc task to copy referenced images also
task :rdoc do
  FileUtils.mkdir_p "doc/rdoc/files/examples/"
  FileUtils.copy "activerecord/examples/associations.png", "doc/rdoc/files/examples/associations.png"
end

desc "Publish API docs for Rails as a whole and for each component"
task :pdoc => :rdoc do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("wrath.rubyonrails.org", "public_html/api", "doc/rdoc").upload
  PROJECTS.each do |project|
    system %(cd #{project} && #{env} #{$0} pdoc)
  end
end

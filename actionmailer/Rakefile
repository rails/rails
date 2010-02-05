require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require File.join(File.dirname(__FILE__), 'lib', 'action_mailer', 'version')

PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_NAME      = 'actionmailer'
PKG_VERSION   = ActionMailer::VERSION::STRING + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

RUBY_FORGE_PROJECT = "actionmailer"
RUBY_FORGE_USER    = "webster132"

desc "Default Task"
task :default => [ :test ]

# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
}

namespace :test do
  task :isolated do
    ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
    Dir.glob("test/**/*_test.rb").all? do |file|
      system(ruby, '-Ilib:test', file)
    end or raise "Failures"
  end
end

# Generate the RDoc documentation
Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Action Mailer -- Easy email delivery and testing"
  rdoc.options << '--line-numbers' << '--inline-source' << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : '../doc/template/horo'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/action_mailer.rb')
  rdoc.rdoc_files.include('lib/action_mailer/*.rb')
  rdoc.rdoc_files.include('lib/action_mailer/delivery_method/*.rb')
}

spec = eval(File.read('actionmailer.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("wrath.rubyonrails.org", "public_html/am", "doc").upload
end

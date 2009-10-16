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
  t.pattern = 'test/*_test.rb'
  t.verbose = true
  t.warning = false
}

task :isolated_test do
  ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
  Dir.glob("test/*_test.rb").all? do |file|
    system(ruby, '-Ilib:test', file)
  end or raise "Failures"
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
}

spec = eval(File.read('actionmailer.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Publish the API documentation"
task :pgem => [:package] do
  require 'rake/contrib/sshpublisher'
  Rake::SshFilePublisher.new("gems.rubyonrails.org", "/u/sites/gems/gems", "pkg", "#{PKG_FILE_NAME}.gem").upload
  `ssh gems.rubyonrails.org '/u/sites/gems/gemupdate.sh'`
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("wrath.rubyonrails.org", "public_html/am", "doc").upload
end

desc "Publish the release files to RubyForge."
task :release => [ :package ] do
  require 'rubyforge'
  require 'rake/contrib/rubyforgepublisher'

  packages = %w( gem tgz zip ).collect{ |ext| "pkg/#{PKG_NAME}-#{PKG_VERSION}.#{ext}" }

  rubyforge = RubyForge.new
  rubyforge.login
  rubyforge.add_release(PKG_NAME, PKG_NAME, "REL #{PKG_VERSION}", *packages)
end

require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/contrib/sshpublisher'
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


# Create compressed packages
spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = PKG_NAME
  s.summary = "Service layer for easy email delivery and testing."
  s.description = %q{Makes it trivial to test and deliver emails sent from a single service layer.}
  s.version = PKG_VERSION

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.rubyforge_project = "actionmailer"
  s.homepage = "http://www.rubyonrails.org"

  s.add_dependency('actionpack', '= 2.3.0' + PKG_BUILD)

  s.has_rdoc = true
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'action_mailer'

  s.files = [ "Rakefile", "install.rb", "README", "CHANGELOG", "MIT-LICENSE" ]
  s.files = s.files + Dir.glob( "lib/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
  s.files = s.files + Dir.glob( "test/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
end
  
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end


desc "Publish the API documentation"
task :pgem => [:package] do 
  Rake::SshFilePublisher.new("gems.rubyonrails.org", "/u/sites/gems/gems", "pkg", "#{PKG_FILE_NAME}.gem").upload
  `ssh gems.rubyonrails.org '/u/sites/gems/gemupdate.sh'`
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do 
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

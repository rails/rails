require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_NAME      = 'actionmailer'
PKG_VERSION   = '0.6.1' + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

desc "Default Task"
task :default => [ :test ]

# Run the unit tests

Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/*_test.rb'
  t.verbose = true
}


# Genereate the RDoc documentation

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Action Mailer -- Easy email delivery and testing"
  rdoc.options << '--line-numbers --inline-source --main README'
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
  s.homepage = "http://actionmailer.rubyonrails.org"

  s.add_dependency('actionpack', '>= 0.9.5')

  s.has_rdoc = true
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'action_mailer'

  s.files = [ "rakefile", "install.rb", "README", "CHANGELOG", "MIT-LICENSE" ]
  s.files = s.files + Dir.glob( "lib/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
  s.files = s.files + Dir.glob( "test/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
end
  
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end


# Publish beta gem
desc "Publish the API documentation"
task :pgem => [:package] do 
  Rake::SshFilePublisher.new("davidhh@comox.textdrive.com", "public_html/gems/gems", "pkg", "#{PKG_FILE_NAME}.gem").upload
end

# Publish documentation
desc "Publish the API documentation"
task :pdoc => [:rdoc] do 
  Rake::SshDirPublisher.new("davidhh@comox.textdrive.com", "public_html/am", "doc").upload
end

desc "Publish to RubyForge"
task :rubyforge do
    Rake::RubyForgePublisher.new('actionmailer', 'webster132').upload
end


desc "Count lines in the main rake file"
task :lines do
  lines = 0
  codelines = 0
  Dir.foreach("lib/action_mailer") { |file_name| 
    next unless file_name =~ /.*rb/
    
    f = File.open("lib/action_mailer/" + file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
  }
  puts "Lines #{lines}, LOC #{codelines}"
end

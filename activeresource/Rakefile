require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'

require File.join(File.dirname(__FILE__), 'lib', 'active_resource', 'version')

PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_NAME      = 'activeresource'
PKG_VERSION   = ActiveResource::VERSION::STRING + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

RUBY_FORGE_PROJECT = "activerecord"
RUBY_FORGE_USER    = "webster132"

PKG_FILES = FileList[
    "lib/**/*", "test/**/*", "[A-Z]*", "Rakefile"
].exclude(/\bCVS\b|~$/)

desc "Default Task"
task :default => [ :test ]

# Run the unit tests

Rake::TestTask.new { |t|
  activesupport_path = "#{File.dirname(__FILE__)}/../activesupport/lib"
  t.libs << activesupport_path if File.directory?(activesupport_path)
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = true
}

task :isolated_test do
  ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
  activesupport_path = "#{File.dirname(__FILE__)}/../activesupport/lib"
  Dir.glob("test/**/*_test.rb").all? do |file|
    system(ruby, '-w', "-Ilib:test:#{activesupport_path}", file)
  end or raise "Failures"
end


# Generate the RDoc documentation

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Active Resource -- Object-oriented REST services"
  rdoc.options << '--line-numbers' << '--inline-source' << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : '../doc/template/horo'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/activeresource.rb')
}


spec = eval(File.read('activeresource.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  for file_name in FileList["lib/active_resource/**/*.rb"]
    next if file_name =~ /vendor/
    f = File.open(file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end


# Publishing ------------------------------------------------------

desc "Publish the beta gem"
task :pgem => [:package] do
  require 'rake/contrib/sshpublisher'
  Rake::SshFilePublisher.new("gems.rubyonrails.org", "/u/sites/gems/gems", "pkg", "#{PKG_FILE_NAME}.gem").upload
  `ssh gems.rubyonrails.org '/u/sites/gems/gemupdate.sh'`
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("wrath.rubyonrails.org", "public_html/ar", "doc").upload
end

desc "Publish the release files to RubyForge."
task :release => [ :package ] do
  `rubyforge login`

  for ext in %w( gem tgz zip )
    release_command = "rubyforge add_release #{PKG_NAME} #{PKG_NAME} 'REL #{PKG_VERSION}' pkg/#{PKG_NAME}-#{PKG_VERSION}.#{ext}"
    puts release_command
    system(release_command)
  end
end

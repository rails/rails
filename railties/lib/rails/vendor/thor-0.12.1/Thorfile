# enconding: utf-8

require File.join(File.dirname(__FILE__), "lib", "thor", "version")
require 'thor/rake_compat'
require 'spec/rake/spectask'
require 'rdoc/task'

GEM_NAME = 'thor'
EXTRA_RDOC_FILES = ["README.rdoc", "LICENSE", "CHANGELOG.rdoc", "VERSION", "Thorfile"]

class Default < Thor
  include Thor::RakeCompat

  Spec::Rake::SpecTask.new(:spec) do |t|
    t.libs << 'lib'
    t.spec_opts = ['--options', "spec/spec.opts"]
    t.spec_files = FileList['spec/**/*_spec.rb']
  end

  Spec::Rake::SpecTask.new(:rcov) do |t|
    t.libs << 'lib'
    t.spec_opts = ['--options', "spec/spec.opts"]
    t.spec_files = FileList['spec/**/*_spec.rb']
    t.rcov = true
    t.rcov_dir = "rcov"
  end

  RDoc::Task.new do |rdoc|
    rdoc.main     = "README.rdoc"
    rdoc.rdoc_dir = "rdoc"
    rdoc.title    = GEM_NAME
    rdoc.rdoc_files.include(*EXTRA_RDOC_FILES)
    rdoc.rdoc_files.include('lib/**/*.rb')
    rdoc.options << '--line-numbers' << '--inline-source'
  end

  begin
    require 'jeweler'
    Jeweler::Tasks.new do |s|
      s.name = GEM_NAME
      s.version = Thor::VERSION
      s.rubyforge_project = "textmate"
      s.platform = Gem::Platform::RUBY
      s.summary = "A scripting framework that replaces rake, sake and rubigen"
      s.email = "ruby-thor@googlegroups.com"
      s.homepage = "http://yehudakatz.com"
      s.description = "A scripting framework that replaces rake, sake and rubigen"
      s.authors = ['Yehuda Katz', 'José Valim']
      s.has_rdoc = true
      s.extra_rdoc_files = EXTRA_RDOC_FILES
      s.require_path = 'lib'
      s.bindir = "bin"
      s.executables = %w( thor rake2thor )
      s.files = s.extra_rdoc_files + Dir.glob("{bin,lib}/**/*")
      s.files.exclude 'spec/sandbox/**/*'
      s.test_files.exclude 'spec/sandbox/**/*'
    end

    Jeweler::GemcutterTasks.new
  rescue LoadError
    puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
  end
end

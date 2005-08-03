require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

require "./lib/switchtower/version"

SOFTWARE_NAME = "switchtower"
SOFTWARE_VERSION = SwitchTower::Version::STRING

desc "Default task"
task :default => [ :test ]

desc "Build documentation"
task :doc => [ :rdoc ]

Rake::TestTask.new do |t|
  t.test_files = Dir["test/*_test.rb"]
  t.verbose = true
end

GEM_SPEC = eval(File.read("#{File.dirname(__FILE__)}/#{SOFTWARE_NAME}.gemspec"))

Rake::GemPackageTask.new(GEM_SPEC) do |p|
  p.gem_spec = GEM_SPEC
  p.need_tar = true
  p.need_zip = true
end

desc "Build the RDoc API documentation"
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title    = "SwitchTower -- A framework for remote command execution"
  rdoc.options << '--line-numbers --inline-source --main README'
  rdoc.rdoc_files.include 'README'
  rdoc.rdoc_files.include 'lib/**/*.rb'
  rdoc.template = "jamis"
end

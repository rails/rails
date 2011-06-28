require 'rake/testtask'
require 'rubygems/package_task'

task :default => :test
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
  t.verbose = true
end

namespace :test do
  Rake::TestTask.new(:isolated) do |t|
    t.pattern = 'test/ts_isolated.rb'
  end
end

# Create compressed packages
dist_dirs = [ "lib", "test"]

spec = eval(File.read('activesupport.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

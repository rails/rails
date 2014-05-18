dir = File.dirname(__FILE__)

require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = Dir.glob("#{dir}/test/cases/**/*_test.rb").sort
  t.warning = true
  t.verbose = true
end

require 'rubygems/package_task'

spec = eval(File.read("#{dir}/activejob.gemspec"))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to rubygems"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

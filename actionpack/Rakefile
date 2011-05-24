#!/usr/bin/env rake
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'

desc "Default Task"
task :default => :test

# Run the unit tests

desc "Run all unit tests"
task :test => [:test_action_pack, :test_active_record_integration]

Rake::TestTask.new(:test_action_pack) do |t|
  t.libs << 'test'

  # make sure we include the tests in alphabetical order as on some systems
  # this will not happen automatically and the tests (as a whole) will error
  t.test_files = Dir.glob('test/{abstract,controller,dispatch,template}/**/*_test.rb').sort

  t.warning = true
  t.verbose = true
end

namespace :test do
  Rake::TestTask.new(:isolated) do |t|
    t.pattern = 'test/ts_isolated.rb'
  end
end

desc 'ActiveRecord Integration Tests'
Rake::TestTask.new(:test_active_record_integration) do |t|
  t.libs << 'test'
  t.test_files = Dir.glob("test/activerecord/*_test.rb")
end

spec = eval(File.read('actionpack.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  for file_name in FileList["lib/**/*.rb"]
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

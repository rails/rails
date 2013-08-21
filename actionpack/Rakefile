require 'rake/testtask'
require 'rubygems/package_task'

test_files = Dir.glob('test/{abstract,controller,dispatch,assertions,journey,routing}/**/*_test.rb')

desc "Default Task"
task :default => :test

# Run the unit tests
Rake::TestTask.new do |t|
  t.libs << 'test'

  # make sure we include the tests in alphabetical order as on some systems
  # this will not happen automatically and the tests (as a whole) will error
  t.test_files = test_files.sort

  t.warning = true
  t.verbose = true
end

namespace :test do
  task :isolated do
    test_files.all? do |file|
      sh(Gem.ruby, '-w', '-Ilib:test', file)
    end or raise "Failures"
  end
end

spec = eval(File.read('actionpack.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to rubygems"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  FileList["lib/**/*.rb"].each do |file_name|
    next if file_name =~ /vendor/
    File.open(file_name, 'r') do |f|
      while line = f.gets
        lines += 1
        next if line =~ /^\s*$/
        next if line =~ /^\s*#/
        codelines += 1
      end
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end

rule '.rb' => '.y' do |t|
  sh "racc -l -o #{t.name} #{t.source}"
end

task compile: 'lib/action_dispatch/journey/parser.rb'

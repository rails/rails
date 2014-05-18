dir = File.dirname(__FILE__)

require 'rake/testtask'

def run_without_aborting(*tasks)
  errors = []

  tasks.each do |task|
    begin
      Rake::Task[task].invoke
    rescue Exception
      errors << task
    end
  end

  abort "Errors running #{errors.join(', ')}" if errors.any?
end



task :default => :test

desc 'Run all adapter tests'
task :test do
  tasks = %w(test_inline test_resque test_sidekiq)
  run_without_aborting(*tasks)
end


%w( inline resque sidekiq ).each do |adapter|
  Rake::TestTask.new("test_#{adapter}") do |t|
    t.libs << 'test'
    t.test_files = FileList['test/cases/**/*_test.rb']
    t.verbose = true
  end

  namespace adapter do
    task :test => "test_#{adapter}"
    task(:env) { ENV['AJADAPTER'] = adapter }
  end

  task "test_#{adapter}" => "#{adapter}:env"
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

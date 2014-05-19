require 'bundler/gem_tasks'

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
  tasks = %w(test_inline test_resque test_sidekiq test_sucker_punch test_delayed_job)
  run_without_aborting(*tasks)
end


%w( inline resque sidekiq sucker_punch delayed_job).each do |adapter|
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

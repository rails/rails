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
  tasks = %w(test_inline test_delayed_job test_que test_queue_classic test_resque test_sidekiq test_sneakers test_sucker_punch test_backburner)
  run_without_aborting(*tasks)
end

%w(inline delayed_job que queue_classic resque sidekiq sneakers sucker_punch backburner).each do |adapter|
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

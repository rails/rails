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

task default: :test

ADAPTERS = %w(inline delayed_job qu que queue_classic resque sidekiq sneakers sucker_punch backburner)

desc 'Run all adapter tests'
task :test do
  tasks = ADAPTERS.map{|a| "test_#{a}" }+["integration_test"]
  run_without_aborting(*tasks)
end

ADAPTERS.each do |adapter|
  Rake::TestTask.new("test_#{adapter}") do |t|
    t.libs << 'test'
    t.test_files = FileList['test/cases/**/*_test.rb']
    t.verbose = true
  end

  namespace adapter do
    task test: "test_#{adapter}"
    task(:env) { ENV['AJADAPTER'] = adapter }
  end

  task "test_#{adapter}" => "#{adapter}:env"
end



desc 'Run all adapter integration tests'
task :integration_test do
  tasks = (ADAPTERS-['inline']).map{|a| "integration_test_#{a}" }
  run_without_aborting(*tasks)
end

(ADAPTERS-['inline']).each do |adapter|
  Rake::TestTask.new("integration_test_#{adapter}") do |t|
    t.libs << 'test'
    t.test_files = FileList['test/integration/**/*_test.rb']
    t.verbose = true
  end

  namespace "integration_#{adapter}" do
    task test: "integration_test_#{adapter}"
    task(:env) do
      ENV['AJADAPTER'] = adapter
      ENV['AJ_INTEGRATION_TESTS'] = "1"
    end
  end

  task "integration_test_#{adapter}" => "integration_#{adapter}:env"
end

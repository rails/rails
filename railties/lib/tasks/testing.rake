TEST_CHANGES_SINCE = Time.now - 600

# Look up tests for recently modified sources.
def recent_tests(source_pattern, test_path, touched_since = 10.minutes.ago)
  FileList[source_pattern].map do |path|
    if File.mtime(path) > touched_since
      test = "#{test_path}/#{File.basename(path, '.rb')}_test.rb"
      test if File.exists?(test)
    end
  end.compact
end


# Recreated here from ActiveSupport because :uncommitted needs it before Rails is available
module Kernel
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end
end

desc 'Test all units and functionals'
task :test do
  Rake::Task["test:units"].invoke       rescue got_error = true
  Rake::Task["test:functionals"].invoke rescue got_error = true
  
  if File.exist?("test/integration")
    Rake::Task["test:integration"].invoke rescue got_error = true
  end

  raise "Test failures" if got_error
end

namespace :test do
  desc 'Test recent changes'
  Rake::TestTask.new(:recent => "db:test:prepare") do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/*.rb', 'test/unit', since) +
      recent_tests('app/controllers/*.rb', 'test/functional', since)

    t.libs << 'test'
    t.verbose = true
    t.test_files = touched.uniq
  end
  
  desc 'Test changes since last checkin (only Subversion)'
  Rake::TestTask.new(:uncommitted => "db:test:prepare") do |t|
    def t.file_list
      changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }

      models      = changed_since_checkin.select { |path| path =~ /app\/models\/.*\.rb/ }
      controllers = changed_since_checkin.select { |path| path =~ /app\/controllers\/.*\.rb/ }  

      unit_tests       = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }
      functional_tests = controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }

      unit_tests.uniq + functional_tests.uniq
    end
    
    t.libs << 'test'
    t.verbose = true
  end

  desc "Run the unit tests in test/unit"
  Rake::TestTask.new(:units => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
  end

  desc "Run the functional tests in test/functional"
  Rake::TestTask.new(:functionals => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/functional/**/*_test.rb'
    t.verbose = true
  end

  desc "Run the integration tests in test/integration"
  Rake::TestTask.new(:integration => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/integration/**/*_test.rb'
    t.verbose = true
  end

  desc "Run the plugin tests in vendor/plugins/**/test (or specify with PLUGIN=name)"
  Rake::TestTask.new(:plugins => :environment) do |t|
    t.libs << "test"

    if ENV['PLUGIN']
      t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/**/test/**/*_test.rb'
    end

    t.verbose = true
  end
end

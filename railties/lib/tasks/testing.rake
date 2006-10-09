TEST_CHANGES_SINCE = Time.now - 600

# Look up tests for recently modified sources.
def recent_tests(source_pattern, test_path, touched_since = 10.minutes.ago)
  FileList[source_pattern].map do |path|
    if File.mtime(path) > touched_since
      tests = []
      source_dir = File.dirname(path).split("/")
      source_file = File.basename(path, '.rb')
      
      # Support subdirs in app/models and app/controllers
      modified_test_path = source_dir.length > 2 ? "#{test_path}/" << source_dir[1..source_dir.length].join('/') : test_path

      # For modified files in app/ run the tests for it. ex. /test/functional/account_controller.rb
      test = "#{modified_test_path}/#{source_file}_test.rb"
      tests.push test if File.exists?(test)

      # For modified files in app, run tests in subdirs too. ex. /test/functional/account/*_test.rb
      test = "#{modified_test_path}/#{File.basename(path, '.rb').sub("_controller","")}"
      FileList["#{test}/*_test.rb"].each { |f| tests.push f } if File.exists?(test)
		
      return tests

    end
  end.flatten.compact
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
  Rake::TestTask.new(:recent => "db:test:prepare") do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/**/*.rb', 'test/unit', since) +
      recent_tests('app/controllers/**/*.rb', 'test/functional', since)

    t.libs << 'test'
    t.verbose = true
    t.test_files = touched.uniq
  end
  Rake::Task['test:recent'].comment = "Test recent changes"
  
  Rake::TestTask.new(:uncommitted => "db:test:prepare") do |t|
    def t.file_list
      changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb/ }  

      unit_tests       = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }
      functional_tests = controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }

      unit_tests.uniq + functional_tests.uniq
    end
    
    t.libs << 'test'
    t.verbose = true
  end
  Rake::Task['test:uncommitted'].comment = "Test changes since last checkin (only Subversion)"

  Rake::TestTask.new(:units => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:units'].comment = "Run the unit tests in test/unit"

  Rake::TestTask.new(:functionals => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/functional/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:functionals'].comment = "Run the functional tests in test/functional"

  Rake::TestTask.new(:integration => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/integration/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:integration'].comment = "Run the integration tests in test/integration"

  Rake::TestTask.new(:plugins => :environment) do |t|
    t.libs << "test"

    if ENV['PLUGIN']
      t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/**/test/**/*_test.rb'
    end

    t.verbose = true
  end
  Rake::Task['test:plugins'].comment = "Run the plugin tests in vendor/plugins/**/test (or specify with PLUGIN=name)"
end

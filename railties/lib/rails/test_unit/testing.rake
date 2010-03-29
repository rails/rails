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
      tests.push test if File.exist?(test)

      # For modified files in app, run tests in subdirs too. ex. /test/functional/account/*_test.rb
      test = "#{modified_test_path}/#{File.basename(path, '.rb').sub("_controller","")}"
      FileList["#{test}/*_test.rb"].each { |f| tests.push f } if File.exist?(test)

      return tests

    end
  end.flatten.compact
end


# Recreated here from ActiveSupport because :uncommitted needs it before Rails is available
module Kernel
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(RUBY_PLATFORM =~ /(:?mswin|mingw)/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end
end

desc 'Run all unit, functional and integration tests'
task :test do
  errors = %w(test:models test:controllers test:helpers).collect do |task|
    begin
      Rake::Task[task].invoke
      nil
    rescue => e
      task
    end
  end.compact
  abort "Errors running #{errors * ', '}!" if errors.any?
end

namespace :test do
  Rake::TestTask.new(:recent => "db:test:prepare") do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/**/*.rb', 'test/models', since) +
      recent_tests('app/models/**/*_observer.rb', 'test/observers', since) +
      recent_tests('app/controllers/**/*.rb', 'test/controllers', since) +
      recent_tests('app/helpers/**/*.rb', 'test/helpers', since)

    t.libs << 'test'
    t.test_files = touched.uniq
  end
  Rake::Task['test:recent'].comment = "Test recent changes"

  Rake::TestTask.new(:uncommitted => "db:test:prepare") do |t|
    def t.file_list
      if File.directory?(".svn")
        changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }
      elsif File.directory?(".git")
        changed_since_checkin = silence_stderr { `git ls-files --modified --others` }.map { |path| path.chomp }
      else
        abort "Not a Subversion or Git checkout."
      end

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb$/ }
      observers   = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*_observer\.rb$/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb$/ }
      helpers     = changed_since_checkin.select { |path| path =~ /app[\\\/]helpers[\\\/].*\.rb$/ }

      model_tests      = models.map { |model| "test/models/#{File.basename(model, '.rb')}_test.rb" }
      observer_tests   = observers.map { |observer| "test/observers/#{File.basename(observer, '.rb')}_test.rb" }
      controller_tests = controllers.map { |controller| "test/controllers/#{File.basename(controller, '.rb')}_test.rb" }
      helper_tests     = helpers.map { |helper| "test/helpers/#{File.basename(helper, '.rb')}_test.rb" }

      (model_tests + observer_tests + controller_tests + helper_tests).uniq
    end

    t.libs << 'test'
  end
  Rake::Task['test:uncommitted'].comment = "Test changes since last checkin (only Subversion and Git)"

  Rake::TestTask.new(:models => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = ['test/models/**/*_test.rb', 'test/observers/**/*_test.rb']
  end
  Rake::Task['test:models'].comment = "Run the unit tests in test/models and test/observers"

  Rake::TestTask.new(:controllers => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/controllers/**/*_test.rb'
  end
  Rake::Task['test:controllers'].comment = "Run the functional and integration tests in test/controllers"

  Rake::TestTask.new(:helpers => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/helpers/**/*_test.rb'
  end
  Rake::Task['test:helpers'].comment = "Run the unit tests in test/helpers"

  Rake::TestTask.new(:benchmark => 'db:test:prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
    t.options = '-- --benchmark'
  end
  Rake::Task['test:benchmark'].comment = 'Benchmark the performance tests'

  Rake::TestTask.new(:profile => 'db:test:prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
  end
  Rake::Task['test:profile'].comment = 'Profile the performance tests'

  Rake::TestTask.new(:plugins => :environment) do |t|
    t.libs << "test"

    if ENV['PLUGIN']
      t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/*/**/test/**/*_test.rb'
    end
  end
  Rake::Task['test:plugins'].comment = "Run the plugin tests in vendor/plugins/*/**/test (or specify with PLUGIN=name)"
end

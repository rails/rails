require 'rbconfig'
require 'rake/testtask'
require 'rails/test_unit/sub_test_task'
require 'active_support/deprecation'

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

      # For modified files in app/ run the tests for it. ex. /test/controllers/account_controller.rb
      test = "#{modified_test_path}/#{source_file}_test.rb"
      tests.push test if File.exist?(test)

      # For modified files in app, run tests in subdirs too. ex. /test/controllers/account/*_test.rb
      test = "#{modified_test_path}/#{File.basename(path, '.rb').sub("_controller","")}"
      FileList["#{test}/*_test.rb"].each { |f| tests.push f } if File.exist?(test)

      return tests

    end
  end.flatten.compact
end


# Recreated here from Active Support because :uncommitted needs it before Rails is available
module Kernel
  remove_method :silence_stderr # Removing old method to prevent method redefined warning
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end
end

task default: :test

desc 'Runs test:units, test:functionals, test:integration together'
task :test do
  info = Rails::TestTask.test_info Rake.application.top_level_tasks
  if info.files.any?
    Rails::TestTask.new('test:single') { |t|
      t.test_files = info.files
    }
    ENV['TESTOPTS'] ||= info.opts
    Rake.application.top_level_tasks.replace info.tasks

    Rake::Task['test:single'].invoke
  else
    Rake::Task[ENV['TEST'] ? 'test:single' : 'test:run'].invoke
  end
end

namespace :test do
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance. See Active Record for an example.
  end

  task :run => ['test:units', 'test:functionals', 'test:integration']

  # Inspired by: http://ngauthier.com/2012/02/quick-tests-with-bash.html
  desc "Run tests quickly by merging all types and not resetting db"
  Rails::TestTask.new(:all) do |t|
    t.pattern = "test/**/*_test.rb"
  end

  namespace :all do
    desc "Run tests quickly, but also reset db"
    task :db => %w[db:test:prepare test:all]
  end

  # Display deprecation message
  task :deprecated do
    ActiveSupport::Deprecation.warn "`rake #{ARGV.first}` is deprecated with no replacement."
  end

  Rake::TestTask.new(recent: ["test:deprecated", "test:prepare"]) do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/**/*.rb', 'test/models', since) +
      recent_tests('app/models/**/*.rb', 'test/unit', since) +
      recent_tests('app/controllers/**/*.rb', 'test/controllers', since) +
      recent_tests('app/controllers/**/*.rb', 'test/functional', since)

    t.test_files = touched.uniq
  end
  Rake::Task['test:recent'].comment = "Deprecated; Test recent changes"

  Rake::TestTask.new(uncommitted: ["test:deprecated", "test:prepare"]) do |t|
    def t.file_list
      if File.directory?(".svn")
        changed_since_checkin = silence_stderr { `svn status` }.split.map { |path| path.chomp[7 .. -1] }
      elsif system "git rev-parse --git-dir 2>&1 >/dev/null"
        changed_since_checkin = silence_stderr { `git ls-files --modified --others --exclude-standard` }.split.map { |path| path.chomp }
      else
        abort "Not a Subversion or Git checkout."
      end

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb$/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb$/ }

      unit_tests       = models.map { |model| "test/models/#{File.basename(model, '.rb')}_test.rb" } +
                         models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" } +
      functional_tests = controllers.map { |controller| "test/controllers/#{File.basename(controller, '.rb')}_test.rb" } +
                         controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }
      (unit_tests + functional_tests).uniq.select { |file| File.exist?(file) }
    end
  end
  Rake::Task['test:uncommitted'].comment = "Deprecated; Test changes since last checkin (only Subversion and Git)"

  Rails::TestTask.new(single: "test:prepare")

  Rails::TestTask.new(models: "test:prepare") do |t|
    t.pattern = 'test/models/**/*_test.rb'
  end

  Rails::TestTask.new(helpers: "test:prepare") do |t|
    t.pattern = 'test/helpers/**/*_test.rb'
  end

  Rails::TestTask.new(units: "test:prepare") do |t|
    t.pattern = 'test/{models,helpers,unit}/**/*_test.rb'
  end

  Rails::TestTask.new(controllers: "test:prepare") do |t|
    t.pattern = 'test/controllers/**/*_test.rb'
  end

  Rails::TestTask.new(mailers: "test:prepare") do |t|
    t.pattern = 'test/mailers/**/*_test.rb'
  end

  Rails::TestTask.new(functionals: "test:prepare") do |t|
    t.pattern = 'test/{controllers,mailers,functional}/**/*_test.rb'
  end

  Rails::TestTask.new(integration: "test:prepare") do |t|
    t.pattern = 'test/integration/**/*_test.rb'
  end
end

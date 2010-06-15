require 'rake/testtask'

# Monkey-patch to silence the description from Rake::TestTask to cut down on rake -T noise
class TestTaskWithoutDescription < Rake::TestTask
  # Create the tasks defined by this task lib.
  def define
    lib_path = @libs.join(File::PATH_SEPARATOR)
    task @name do
      run_code = ''
      RakeFileUtils.verbose(@verbose) do
        run_code =
          case @loader
          when :direct
            "-e 'ARGV.each{|f| load f}'"
          when :testrb
            "-S testrb #{fix}"
          when :rake
            rake_loader
          end
        @ruby_opts.unshift( "-I\"#{lib_path}\"" )
        @ruby_opts.unshift( "-w" ) if @warning
        ruby @ruby_opts.join(" ") +
          " \"#{run_code}\" " +
          file_list.collect { |fn| "\"#{fn}\"" }.join(' ') +
          " #{option_list}"
      end
    end
    self
  end
end


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


# Recreated here from Active Support because :uncommitted needs it before Rails is available
module Kernel
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(Config::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end
end

desc 'Runs test:unit, test:functional, test:integration together (also available: test:benchmark, test:profile, test:plugins)'
task :test do
  errors = %w(test:units test:functionals test:integration).collect do |task|
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
  task :prepare do
    # Placeholder task for other Railtie and plugins to enhance. See Active Record for an example.
  end

  Rake::TestTask.new(:recent => "test:prepare") do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/**/*.rb', 'test/unit', since) +
      recent_tests('app/controllers/**/*.rb', 'test/functional', since)

    t.libs << 'test'
    t.test_files = touched.uniq
  end
  Rake::Task['test:recent'].comment = "Test recent changes"

  Rake::TestTask.new(:uncommitted => "test:prepare") do |t|
    def t.file_list
      if File.directory?(".svn")
        changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }
      elsif File.directory?(".git")
        changed_since_checkin = silence_stderr { `git ls-files --modified --others` }.map { |path| path.chomp }
      else
        abort "Not a Subversion or Git checkout."
      end

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb$/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb$/ }

      unit_tests       = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }
      functional_tests = controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }

      unit_tests.uniq + functional_tests.uniq
    end

    t.libs << 'test'
  end
  Rake::Task['test:uncommitted'].comment = "Test changes since last checkin (only Subversion and Git)"

  TestTaskWithoutDescription.new(:units => "test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
  end

  TestTaskWithoutDescription.new(:functionals => "test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/functional/**/*_test.rb'
  end

  TestTaskWithoutDescription.new(:integration => "test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/integration/**/*_test.rb'
  end

  TestTaskWithoutDescription.new(:benchmark => 'test:prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
    t.options = '-- --benchmark'
  end

  TestTaskWithoutDescription.new(:profile => 'test:prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
  end

  TestTaskWithoutDescription.new(:plugins => :environment) do |t|
    t.libs << "test"

    if ENV['PLUGIN']
      t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/*/**/test/**/*_test.rb'
    end
  end
end

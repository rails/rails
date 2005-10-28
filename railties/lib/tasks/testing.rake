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

desc 'Test recent changes'
Rake::TestTask.new(:recent => [ :prepare_test_database ]) do |t|
  since = TEST_CHANGES_SINCE
  touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
    recent_tests('app/models/*.rb', 'test/unit', since) +
    recent_tests('app/controllers/*.rb', 'test/functional', since)

  t.libs << 'test'
  t.verbose = true
  t.test_files = touched.uniq
end

desc "Run the unit tests in test/unit"
Rake::TestTask.new(:test_units => [ :prepare_test_database ]) do |t|
  t.libs << "test"
  t.pattern = 'test/unit/**/*_test.rb'
  t.verbose = true
end

desc "Run the functional tests in test/functional"
Rake::TestTask.new(:test_functional => [ :prepare_test_database ]) do |t|
  t.libs << "test"
  t.pattern = 'test/functional/**/*_test.rb'
  t.verbose = true
end

desc "Run the plugin tests in vendor/plugins/**/test (or specify with PLUGIN=name)"
Rake::TestTask.new(:test_plugins => :environment) do |t|
  t.libs << "test"
  
  if ENV['PLUGIN']
    t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
  else
    t.pattern = 'vendor/plugins/**/test/**/*_test.rb'
  end

  t.verbose = true
end

desc "Run all the tests on a fresh test database"
task :default do
  Rake::Task[:test_units].invoke      rescue got_error = true
  Rake::Task[:test_functional].invoke rescue got_error = true
  raise "Test failures" if got_error
end

task :environment do
  require(File.join(RAILS_ROOT, 'config', 'environment'))
end


desc "Clears all *.log files in log/"
task :clear_logs do
  FileList["log/*.log"].each do |log_file|
    f = File.open(log_file, "w")
    f.close
  end
end

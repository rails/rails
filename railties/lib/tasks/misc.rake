desc "Run all the tests on a fresh test database"
task :default => [ :test_units, :test_functional ]

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

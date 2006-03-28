task :default => :test
task :environment do
  require(File.join(RAILS_ROOT, 'config', 'environment'))
end
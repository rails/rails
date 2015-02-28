desc "Restart app by touching tmp/restart.txt"
task restart: :environment do
  FileUtils.touch('tmp/restart.txt')
end

desc "Restart app by touching tmp/restart.txt"
task :restart do
  FileUtils.touch('tmp/restart.txt')
end

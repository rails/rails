desc "Restart app by touching tmp/restart.txt"
task :restart => :add_tmp_if_missing do
  FileUtils.touch('tmp/restart.txt')
end

task :add_tmp_if_missing do
  FileUtils.mkdir_p('tmp')
end

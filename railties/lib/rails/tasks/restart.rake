require 'fileutils'

desc "Restart app by touching tmp/restart.txt"
task :restart do
  FileUtils.mkdir_p('tmp')
  FileUtils.touch('tmp/restart.txt')
  FileUtils.rm_f('tmp/pids/server.pid')
end

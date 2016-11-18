desc "Restart app by touching tmp/restart.txt"
task :restart do
  verbose(false) do
    mkdir_p "tmp"
    touch "tmp/restart.txt"
    rm_f "tmp/pids/server.pid"
  end
end

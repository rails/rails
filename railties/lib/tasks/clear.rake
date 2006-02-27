namespace :clear do
  desc "Truncates all *.log files in log/ to zero bytes"
  task :logs do
    FileList["log/*.log"].each do |log_file|
      f = File.open(log_file, "w")
      f.close
    end
  end

  desc "Clear session, cache, and socket files from tmp/"
  task :tmp => [ "clear:tmp:sesions",  "clear:tmp:cache", "clear:tmp:sockets"]

  namespace :tmp do
    desc "Clears all files in tmp/sessions"
    task :sessions do
      FileUtils.rm(Dir['tmp/sessions/[^.]*'])
    end

    desc "Clears all files and directories in tmp/cache"
    task :cache do
      FileUtils.rm_rf(Dir['tmp/cache/[^.]*'])
    end

    desc "Clears all ruby_sess.* files in tmp/sessions"
    task :sockets do
      FileUtils.rm(Dir['tmp/sockets/[^.]*'])
    end
  end
end
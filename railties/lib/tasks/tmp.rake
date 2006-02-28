namespace :tmp do
  desc "Clear session, cache, and socket files from tmp/"
  task :clear => [ "tmp:sesions:clear",  "tmp:cache:clear", "tmp:sockets:clear"]

  desc "Creates tmp directories for sessions, cache, and sockets"
  task :create do
    FileUtils.mkdir "tmp"
    FileUtils.mkdir "tmp/sessions"
    FileUtils.mkdir "tmp/cache"
    FileUtils.mkdir "tmp/sockets"
  end

  desc "Clears all files in tmp/sessions"
  task :clear_sessions do
    FileUtils.rm(Dir['tmp/sessions/[^.]*'])
  end

  desc "Clears all files and directories in tmp/cache"
  task :clear_cache do
    FileUtils.rm_rf(Dir['tmp/cache/[^.]*'])
  end

  desc "Clears all ruby_sess.* files in tmp/sessions"
  task :clear_sockets do
    FileUtils.rm(Dir['tmp/sockets/[^.]*'])
  end
end
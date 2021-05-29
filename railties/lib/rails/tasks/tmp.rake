# frozen_string_literal: true

namespace :tmp do
  desc "Clear cache, socket and screenshot files from tmp/ (narrow w/ tmp:cache:clear, tmp:sockets:clear, tmp:screenshots:clear)"
  task clear: ["tmp:cache:clear", "tmp:sockets:clear", "tmp:screenshots:clear", "tmp:storage:clear"]

  tmp_dirs = [ "tmp/cache",
               "tmp/sockets",
               "tmp/pids",
               "tmp/cache/assets" ]

  tmp_dirs.each { |d| directory d }

  desc "Creates tmp directories for cache, sockets, and pids"
  task create: tmp_dirs

  namespace :cache do
    # desc "Clears all files and directories in tmp/cache"
    task :clear do
      rm_rf Dir["tmp/cache/[^.]*"], verbose: false
    end
  end

  namespace :sockets do
    # desc "Clears all files in tmp/sockets"
    task :clear do
      rm Dir["tmp/sockets/[^.]*"], verbose: false
    end
  end

  namespace :pids do
    # desc "Clears all files in tmp/pids"
    task :clear do
      rm Dir["tmp/pids/[^.]*"], verbose: false
    end
  end

  namespace :screenshots do
    # desc "Clears all files in tmp/screenshots"
    task :clear do
      rm Dir["tmp/screenshots/[^.]*"], verbose: false
    end
  end

  namespace :storage do
    # desc "Clear all files and directories in tmp/storage"
    task :clear do
      rm_rf Dir["tmp/storage/[^.]*"], verbose: false
    end
  end
end

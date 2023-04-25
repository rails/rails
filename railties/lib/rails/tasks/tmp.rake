# frozen_string_literal: true

namespace :tmp do
  desc "Clear cache, screenshot, socket, and storage files from tmp/ (narrow w/ tmp:cache:clear, tmp:screenshots:clear, tmp:sockets:clear, tmp:storage:clear)"
  task clear: ["tmp:cache:clear", "tmp:screenshots:clear", "tmp:sockets:clear", "tmp:storage:clear"]

  tmp_dirs = [ "tmp/cache/assets",
               "tmp/pids",
               "tmp/screenshots",
               "tmp/sockets",
               "tmp/storage" ]

  tmp_dirs.each { |d| directory d }

  desc "Create tmp directories for cache, pids, screenshots, sockets, and storage"
  task create: tmp_dirs

  namespace :cache do
    # desc "Clear all files and directories in tmp/cache"
    task :clear do
      rm_rf Dir["tmp/cache/[^.]*"], verbose: false
    end
  end

  namespace :sockets do
    # desc "Clear all files in tmp/sockets"
    task :clear do
      rm Dir["tmp/sockets/[^.]*"], verbose: false
    end
  end

  namespace :pids do
    # desc "Clear all files in tmp/pids"
    task :clear do
      rm Dir["tmp/pids/[^.]*"], verbose: false
    end
  end

  namespace :screenshots do
    # desc "Clear all files in tmp/screenshots"
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

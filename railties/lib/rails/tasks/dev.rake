namespace :dev do
  task :cache do
    desc 'Toggle development mode caching on/off'
    if File.exist? 'tmp/caching-dev.txt'
      File.delete 'tmp/caching-dev.txt'
      puts 'Development mode is no longer being cached.'
    else
      FileUtils.touch 'tmp/caching-dev.txt'
      puts 'Development mode is now being cached.'
    end
    FileUtils.touch 'tmp/restart.txt'
  end
end

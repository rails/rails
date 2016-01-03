require 'rails/command'

module Rails
  module Commands
    # This is a wrapper around the Rails dev:cache command
    class DevCache < Command
      set_banner :dev_cache, 'Toggle development mode caching on/off'
      def dev_cache
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
  end
end

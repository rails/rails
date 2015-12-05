require 'rails/commands/command'

module Rails
  module Commands
    class Restart < Command
      set_banner :restart, 'Restart app by touching tmp/restart.txt'

      def restart
        FileUtils.mkdir_p('tmp')
        FileUtils.touch('tmp/restart.txt')
      end
    end
  end
end

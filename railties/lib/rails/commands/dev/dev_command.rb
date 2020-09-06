# frozen_string_literal: true

require 'rails/dev_caching'

module Rails
  module Command
    class DevCommand < Base # :nodoc:
      no_commands do
        def help
          say 'rails dev:cache # Toggle development mode caching on/off.'
        end
      end

      def cache
        Rails::DevCaching.enable_by_file
      end
    end
  end
end

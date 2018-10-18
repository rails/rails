# frozen_string_literal: true

require "rails/dev_caching"

module Rails
  module Command
    class DevCommand < Base # :nodoc:
      def help
        say "rails dev:cache # Toggle development mode caching on/off."
      end

      def cache
        Rails::DevCaching.enable_by_file
      end
    end
  end
end

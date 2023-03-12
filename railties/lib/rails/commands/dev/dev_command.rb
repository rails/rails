# frozen_string_literal: true

module Rails
  module Command
    class DevCommand < Base # :nodoc:
      desc "cache", "Toggle development mode caching on/off"
      def cache
        require "rails/dev_caching"
        Rails::DevCaching.enable_by_file
      end
    end
  end
end

# frozen_string_literal: true

module Rails
  autoload :DevCaching, "rails/dev_caching"

  module Command
    class DevCommand < Base # :nodoc:
      desc "cache", "Toggle development mode caching on/off"
      def cache
        Rails::DevCaching.enable_by_file
      end
    end
  end
end

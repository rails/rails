# frozen_string_literal: true

module Rails
  module Command
    class CacheCommand < Base # :nodoc:
      desc "Clear all files and directories in tmp/cache"
      def clear
        rm_rf Dir["tmp/cache/[^.]*"], verbose: false
      end
    end
  end
end

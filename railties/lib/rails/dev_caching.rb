# frozen_string_literal: true

require "fileutils"

module Rails
  module DevCaching # :nodoc:
    class << self
      FILE = "tmp/caching-dev.txt"

      def enable_by_file
        FileUtils.mkdir_p("tmp")

        if File.exist?(FILE)
          delete_cache_file
          puts "Action Controller caching disabled for development mode."
        else
          create_cache_file
          puts "Action Controller caching enabled for development mode."
        end

        FileUtils.touch "tmp/restart.txt"
      end

      def enable_by_argument(caching)
        FileUtils.mkdir_p("tmp")

        if caching
          create_cache_file
        elsif caching == false && File.exist?(FILE)
          delete_cache_file
        end
      end

      private
        def create_cache_file
          FileUtils.touch FILE
        end

        def delete_cache_file
          File.delete FILE
        end
    end
  end
end

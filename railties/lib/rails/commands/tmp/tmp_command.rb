# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    class TmpCommand < Base # :nodoc:
      include Rails::Command::Tmp::Helpers

      desc :clear, "Clear cache, socket and screenshot files from tmp/ (narrow w/ tmp:cache:clear, tmp:sockets:clear, tmp:screenshots:clear)"
      def clear
        clear_tmp_dir "cache"
        clear_tmp_dir "sockets"
        clear_tmp_dir "screenshots"
        clear_tmp_dir "storage"
      end

      desc :create, "Create tmp directories for cache, sockets, and pids"
      def create
        create_tmp_dir "cache"
        create_tmp_dir "sockets"
        create_tmp_dir "pids"
        create_tmp_dir "cache/assets"
      end
    end
  end
end

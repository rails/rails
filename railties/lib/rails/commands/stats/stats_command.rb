# frozen_string_literal: true

module Rails
  module Command
    class StatsCommand < Base # :nodoc:
      desc "stats", "Report code statistics (KLOCs, etc) from the application or engine"
      def perform
        require "rails/code_statistics"
        boot_application!

        stat_directories = Rails::CodeStatistics.directories.map do |name, dir|
          [name, Rails::Command.application_root.join(dir)]
        end.select { |name, dir| File.directory?(dir) }

        Rails::CodeStatistics.new(*stat_directories).to_s
      end
    end
  end
end

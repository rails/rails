# frozen_string_literal: true

module Rails
  module Command
    class ClearCommand < Base # :nodoc:
      desc "clear", "Truncate log/*.log files"
      option :logs, type: :array, lazy_default: [],
        desc: "Truncate log/*.log files for specified environments to zero bytes. If no environments are specified, truncate logs for all environments."
      def clear
        if options[:logs].empty?
          environments = all_environments
        else
          environments = options[:logs]
        end
        log_files_for(environments).each { |file| file.truncate(0) }
      end

      private
        def log_files_for(environments)
          pattern = environments == ["all"] ? "*" : "{#{environments.join(",")}}"
          Rails::Command.application_root.glob("log/#{pattern}.log").select(&:file?)
        end

        def all_environments
          Rails::Command.application_root.glob("config/environments/*.rb")
            .map { |fname| File.basename(fname, ".*") }
        end
    end
  end
end

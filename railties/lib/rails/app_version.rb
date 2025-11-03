# frozen_string_literal: true

module Rails
  # Manages the application revision for deployment tracking and error reporting.
  #
  # The revision is determined in order of precedence:
  # 1. Custom proc/string via config.revision
  # 2. REVISION file in application root (created by deployment tools like Capistrano)
  # 3. nil if none available
  module AppVersion
    class << self
      def revision(config_revision)
        @revision ||= load_revision(config_revision)
      end

      def reset!
        @revision = nil
      end

      private
        def load_revision(config_revision)
          custom_revision(config_revision) || read_revision_file
        end

        def custom_revision(config_revision)
          return unless config_revision

          case config_revision
          when Proc
            config_revision.call&.to_s&.strip.presence
          when String
            config_revision.strip.presence
          end
        end

        def read_revision_file
          revision_file = Rails.root.join("REVISION")
          revision_file.read.strip.presence if revision_file.exist?
        rescue
          nil
        end
    end
  end
end

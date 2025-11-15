# frozen_string_literal: true

module Rails
  # This module manages the application version and revision information.
  # It provides a unified way to track and expose version details throughout
  # the Rails application, similar to how Rails::Info exposes system information.
  module AppVersion
    # Semantic version representation with revision support
    class Version < Gem::Version
      attr_reader :major, :minor, :patch, :pre, :revision

      def self.create(version_string, revision = nil)
        new(version_string).tap { |v| v.set_revision(revision) }
      end

      def set_revision(revision)
        @revision = revision&.to_s&.strip
      end

      def full(show_revision: true)
        return to_s unless show_revision && revision.present?
        return to_s if revision == "0"
        "#{self} (#{short_revision})"
      end

      def to_cache_key
        parts = [major, minor]
        parts << patch if patch.present?
        parts << pre if prerelease?
        parts.join("-")
      end

      def short_revision
        revision.to_s[0, 8].presence
      end

      def prerelease?
        pre.present?
      end

      def production_ready?
        !prerelease? && major.to_i > 0
      end

      protected
        def initialize(version)
          super
          parse_version(version)
        end

      private
        def parse_version(version_string)
          if version_string.blank?
            raise ArgumentError, "Version string cannot be nil or empty"
          end

          parts = version_string.to_s.split(".")
          pre_parts = parts.last.to_s.split("-", 2)

          if pre_parts.length > 1
            parts[-1] = pre_parts[0]
            @pre = pre_parts[1]
          end

          @major = parts[0].to_i
          @minor = parts[1].to_i
          @patch = parts[2]&.to_i
        end
    end

    class << self
      attr_accessor :version_instance, :app_environment

      def version
        @version_instance ||= load_version
      end

      def env
        @app_environment ||= load_environment
      end

      def revision
        @revision ||= load_revision
      end

      def load_version
        version_string = read_version_file || ENV["RAILS_APP_VERSION"] || "0.0.0"
        Version.create(version_string, revision)
      end

      def load_environment
        ActiveSupport::StringInquirer.new(
          ENV.fetch("RAILS_APP_ENV", Rails.env)
        )
      end

      def load_revision
        read_revision_file || read_git_revision || "0"
      end

      private
        def read_version_file
          version_file = Rails.root.join("VERSION")
          version_file.read.strip if version_file.exist?
        rescue
          nil
        end

        def read_revision_file
          revision_file = Rails.root.join("REVISION")
          revision_file.read.strip if revision_file.exist?
        rescue
          nil
        end

        def read_git_revision
          `git rev-parse HEAD 2>/dev/null`.strip.presence
        rescue
          nil
        end
    end
  end
end

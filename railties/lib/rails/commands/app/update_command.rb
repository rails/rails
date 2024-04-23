# frozen_string_literal: true

require "rails/app_updater"

module Rails
  module Command
    module App
      class UpdateCommand < Base # :nodoc:
        desc "update", "Update configs and some other initially generated files (or use just update:configs or update:bin)"
        def perform
          configs
          bin
          active_storage
          Rails::AppUpdater.invoke_from_app_generator :display_upgrade_guide_info
        end

        desc "configs", "Update configuration files in the application config/ directory", hide: true
        def configs
          require_application!
          Rails::AppUpdater.invoke_from_app_generator :create_boot_file
          Rails::AppUpdater.invoke_from_app_generator :update_config_files
        end

        desc "bin", "Update executables in the application bin/ directory", hide: true
        def bin
          require_application!
          Rails::AppUpdater.invoke_from_app_generator :update_bin_files
        end

        desc "active_storage", "Run the active_storage:update command", hide: true
        def active_storage
          require_application!
          Rails::AppUpdater.invoke_from_app_generator :update_active_storage
        end
      end
    end
  end
end

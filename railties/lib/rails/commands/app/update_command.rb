# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/app/app_generator"

module Rails
  module Command
    module App
      class UpdateCommand < Base # :nodoc:
        desc "update", "Update configs and some other initially generated files (or use just update:configs or update:bin)"
        def perform
          configs
          bin
          active_storage
          display_upgrade_guide_info
        end

        desc "configs", "Update config files in the application config/ directory", hide: true
        def configs
          require_application!
          app_generator.create_boot_file
          app_generator.update_config_files
        end

        desc "bin", "Add or update executables in the application bin/ directory", hide: true
        def bin
          require_application!
          app_generator.update_bin_files
        end

        desc "active_storage", "Run the active_storage:update command", hide: true
        def active_storage
          require_application!
          app_generator.update_active_storage
        end

        private
          def display_upgrade_guide_info
            say "\nAfter this, check Rails upgrade guide at https://guides.rubyonrails.org/upgrading_ruby_on_rails.html for more details about upgrading your app."
          end

          def app_generator
            @app_generator ||= begin
              gen = Rails::Generators::AppGenerator.new(["rails"], generator_options, destination_root: Rails.root)
              gen.send(:valid_const?) unless File.exist?(Rails.root.join("config", "application.rb"))
              gen
            end
          end

          def generator_options
            options = { api: !!Rails.application.config.api_only, update: true }
            options[:name]                = Rails.application.class.name.chomp("::Application").underscore
            options[:skip_active_job]     = !defined?(ActiveJob::Railtie)
            options[:skip_active_record]  = !defined?(ActiveRecord::Railtie)
            options[:skip_active_storage] = !defined?(ActiveStorage::Engine)
            options[:skip_action_mailer]  = !defined?(ActionMailer::Railtie)
            options[:skip_action_mailbox] = !defined?(ActionMailbox::Engine)
            options[:skip_action_text]    = !defined?(ActionText::Engine)
            options[:skip_action_cable]   = !defined?(ActionCable::Engine)
            options[:skip_test]           = !defined?(Rails::TestUnitRailtie)
            options[:skip_system_test]    = Rails.application.config.generators.system_tests.nil?
            options[:asset_pipeline]      = asset_pipeline
            options[:skip_asset_pipeline] = asset_pipeline.nil?
            options[:skip_bootsnap]       = !defined?(Bootsnap)
            options
          end

          def asset_pipeline
            case
            when defined?(Sprockets::Railtie)
              "sprockets"
            when defined?(Propshaft::Railtie)
              "propshaft"
            else
              nil
            end
          end
      end
    end
  end
end

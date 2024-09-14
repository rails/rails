# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/app/app_generator"

module Rails
  module Command
    module App
      class UpdateCommand < Base # :nodoc:
        include Thor::Actions
        add_runtime_options!

        desc "update", "Update configs and some other initially generated files (or use just update:configs or update:bin)"
        def perform
          configs
          bin
          public_directory
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

        desc "public_directory", "Add or update files in the application public/ directory", hide: true
        def public_directory
          require_application!
          app_generator.create_public_files
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
            {
              api:                 !!Rails.application.config.api_only,
              update:              true,
              name:                Rails.application.class.name.chomp("::Application").underscore,
              skip_active_job:     !defined?(ActiveJob::Railtie),
              skip_active_record:  !defined?(ActiveRecord::Railtie),
              skip_active_storage: !defined?(ActiveStorage::Engine),
              skip_action_mailer:  !defined?(ActionMailer::Railtie),
              skip_action_mailbox: !defined?(ActionMailbox::Engine),
              skip_action_text:    !defined?(ActionText::Engine),
              skip_action_cable:   !defined?(ActionCable::Engine),
              skip_brakeman:       skip_gem?("brakeman"),
              skip_rubocop:        skip_gem?("rubocop"),
              skip_test:           !defined?(Rails::TestUnitRailtie),
              skip_system_test:    Rails.application.config.generators.system_tests.nil?,
              skip_asset_pipeline: asset_pipeline.nil?,
              skip_bootsnap:       !defined?(Bootsnap),
            }.merge(options)
          end

          def asset_pipeline
            "propshaft" if defined?(Propshaft::Railtie)
          end

          def skip_gem?(gem_name)
            gem gem_name
            false
          rescue LoadError
            true
          end
      end
    end
  end
end

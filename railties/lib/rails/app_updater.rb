# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/app/app_generator"

module Rails
  class AppUpdater # :nodoc:
    class << self
      def invoke_from_app_generator(method)
        app_generator.send(method)
      end

      def app_generator
        @app_generator ||= begin
          gen = Rails::Generators::AppGenerator.new ["rails"], generator_options, destination_root: Rails.root
          gen.send(:valid_const?) unless File.exist?(Rails.root.join("config", "application.rb"))
          gen
        end
      end

      private
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

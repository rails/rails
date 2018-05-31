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
          File.exist?(Rails.root.join("config", "application.rb")) ? gen.send(:app_const) : gen.send(:valid_const?)
          gen
        end
      end

      private
        def generator_options
          options = { api: !!Rails.application.config.api_only, update: true }
          options[:skip_yarn] = !File.exist?(Rails.root.join("bin", "yarn"))
          options[:skip_active_record]  = !defined?(ActiveRecord::Railtie)
          options[:skip_active_storage] = !defined?(ActiveStorage::Engine) || !defined?(ActiveRecord::Railtie)
          options[:skip_action_mailer]  = !defined?(ActionMailer::Railtie)
          options[:skip_action_cable]   = !defined?(ActionCable::Engine)
          options[:skip_sprockets]      = !defined?(Sprockets::Railtie)
          options[:skip_puma]           = !defined?(Puma)
          options[:skip_bootsnap]       = !defined?(Bootsnap)
          options[:skip_spring]         = !defined?(Spring)
          options
        end
    end
  end
end

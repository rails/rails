# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/devcontainer/devcontainer_generator"

module Rails
  module Command
    class DevcontainerCommand < Base # :nodoc:
      desc "devcontainer", "Generate a Dev Container setup based on current application configuration"
      def perform(*)
        boot_application!

        say "Generating Dev Container with the following options:"
        devcontainer_options.each do |option, value|
          say "#{option}: #{value}"
        end

        Rails::Generators::DevcontainerGenerator.new([], devcontainer_options).invoke_all
      end

      private
        def devcontainer_options
          @devcontainer_options ||= {
            app_name: Rails.application.railtie_name.chomp("_application"),
            database: !!defined?(ActiveRecord) && database,
            active_storage: !!defined?(ActiveStorage),
            redis: !!(defined?(ActionCable) || defined?(ActiveJob)),
            system_test: File.exist?("test/application_system_test_case.rb"),
            node: File.exist?(".node-version"),
          }
        end

        def database
          adapter = ActiveRecord::Base.connection_db_config.adapter
          adapter == "mysql2" ? "mysql" : adapter
        end
    end
  end
end

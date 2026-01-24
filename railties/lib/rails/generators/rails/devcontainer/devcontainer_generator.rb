# frozen_string_literal: true

require "rails/generators"

module Rails
  module Generators
    class DevcontainerGenerator < Base # :nodoc:
      class_option :app_name, type: :string, default: "rails_app",
                   desc: "Name of the app"

      class_option :app_folder, type: :string, default: nil,
                   desc: "The folder name where the app is generated"

      class_option :database, enum: Database::DATABASES, type: :string, default: "sqlite3",
                   desc: "Include configuration for selected database"

      class_option :redis, type: :boolean, default: true,
                   desc: "Include configuration for Redis"

      class_option :system_test, type: :boolean, default: true,
                   desc: "Include configuration for System Tests"

      class_option :active_storage, type: :boolean, default: true,
                   desc: "Include configuration for Active Storage"

      class_option :node, type: :boolean, default: false,
                   desc: "Include configuration for Node"

      class_option :dev, type: :boolean, default: false,
                    desc: "For applications pointing to a local Rails checkout"

      class_option :kamal, type: :boolean, default: true,
                    desc: "Include configuration for Kamal"

      class_option :skip_solid, type: :boolean, default: nil,
                    desc: "Skip Solid Cache, Queue, and Cable setup"

      source_paths << File.expand_path(File.join(base_name, "app", "templates"), base_root)

      def create_devcontainer
        empty_directory ".devcontainer"

        template "devcontainer/devcontainer.json", ".devcontainer/devcontainer.json"
        template "devcontainer/Dockerfile", ".devcontainer/Dockerfile"
        template "devcontainer/compose.yaml", ".devcontainer/compose.yaml"
      end

      def update_application_system_test_case
        return unless options[:system_test]

        system_test_case_path = File.expand_path "test/application_system_test_case.rb", destination_root
        return unless File.exist? system_test_case_path

        gsub_file(system_test_case_path, /^\s*driven_by\b.*/, system_test_configuration)
      end

      def update_database_yml
        # Only postgresql has devcontainer specific configuration, so only update database.yml if we are using postgres
        return unless options[:database] == "postgresql"

        template("config/databases/#{options[:database]}.yml", "config/database.yml")
      end

      private
        def devcontainer?
          true
        end

        def app_name
          options[:app_name]
        end

        def app_folder
          options[:app_folder] || app_name
        end

        def dependencies
          return @dependencies if @dependencies

          @dependencies = []

          @dependencies << "selenium" if options[:system_test]
          @dependencies << "redis" if options[:redis]
          @dependencies << database.name if database.service
          @dependencies
        end

        def container_env
          return @container_env if @container_env

          @container_env = {}

          @container_env["CAPYBARA_SERVER_PORT"] = "45678" if options[:system_test]
          @container_env["SELENIUM_HOST"] = "selenium" if options[:system_test]
          @container_env["REDIS_URL"] = "redis://redis:6379/1" if options[:redis]
          @container_env["KAMAL_REGISTRY_PASSWORD"] = "$KAMAL_REGISTRY_PASSWORD" if options[:kamal]
          @container_env["DB_HOST"] = database.name if database.service

          @container_env
        end

        def volumes
          return @volumes if @volumes

          @volumes = []

          @volumes << "redis-data" if options[:redis]
          @volumes << database.volume if database.volume

          @volumes
        end

        def features
          return @features if @features

          @features = {
            "ghcr.io/devcontainers/features/github-cli:1" => {}
          }

          @features["ghcr.io/rails/devcontainer/features/activestorage"] = {} if options[:active_storage]
          @features["ghcr.io/devcontainers/features/node:1"] = {} if options[:node]
          @features["ghcr.io/devcontainers/features/docker-outside-of-docker:1"] = { moby: false } if options[:kamal]

          @features.merge!(database.feature) if database.feature

          @features
        end

        def mounts
          return @mounts if @mounts

          @mounts = []

          @mounts << local_rails_mount if options[:dev]

          @mounts
        end

        def forward_ports
          return @forward_ports if @forward_ports

          @forward_ports = [3000]
          @forward_ports << database.port if database.port
          @forward_ports << 6379 if options[:redis]

          @forward_ports
        end

        def database
          @database ||= Database.build(options[:database])
        end

        def devcontainer_db_service_yaml(**options)
          return unless service = database.service

          { database.name => service }.to_yaml(**options)[4..-1]
        end

        def local_rails_mount
          {
            type: "bind",
            source: Rails::Generators::RAILS_DEV_PATH,
            target: Rails::Generators::RAILS_DEV_PATH
          }
        end

        def system_test_configuration
          optimize_indentation(<<-'RUBY', 2).chomp
            if ENV["CAPYBARA_SERVER_PORT"]
              served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

              driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: {
                browser: :remote,
                url: "http://#{ENV["SELENIUM_HOST"]}:4444"
              }
            else
              driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
            end
          RUBY
        end
    end
  end
end

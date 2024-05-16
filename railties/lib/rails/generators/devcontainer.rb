# frozen_string_literal: true

module Rails
  module Generators
    module Devcontainer
      private
        def devcontainer_dependencies
          return @devcontainer_dependencies if @devcontainer_dependencies

          @devcontainer_dependencies = []

          @devcontainer_dependencies << "selenium" if depends_on_system_test?
          @devcontainer_dependencies << "redis" if devcontainer_needs_redis?
          @devcontainer_dependencies << database.name if database.service
          @devcontainer_dependencies
        end

        def devcontainer_variables
          return @devcontainer_variables if @devcontainer_variables

          @devcontainer_variables = {}

          @devcontainer_variables["CAPYBARA_SERVER_PORT"] = "45678" if depends_on_system_test?
          @devcontainer_variables["SELENIUM_HOST"] = "selenium" if depends_on_system_test?
          @devcontainer_variables["REDIS_URL"] = "redis://redis:6379/1" if devcontainer_needs_redis?
          @devcontainer_variables["DB_HOST"] = database.name if database.service

          @devcontainer_variables
        end

        def devcontainer_volumes
          return @devcontainer_volumes if @devcontainer_volumes

          @devcontainer_volumes = []

          @devcontainer_volumes << "redis-data" if devcontainer_needs_redis?
          @devcontainer_volumes << database.volume if database.volume

          @devcontainer_volumes
        end

        def devcontainer_features
          return @devcontainer_features if @devcontainer_features

          @devcontainer_features = {
            "ghcr.io/devcontainers/features/github-cli:1" => {}
          }

          @devcontainer_features["ghcr.io/rails/devcontainer/features/activestorage"] = {} unless options[:skip_active_storage]
          @devcontainer_features["ghcr.io/devcontainers/features/node:1"] = {} if using_node?

          @devcontainer_features.merge!(database.feature) if database.feature

          @devcontainer_features
        end

        def devcontainer_mounts
          return @devcontainer_mounts if @devcontainer_mounts

          @devcontainer_mounts = []

          @devcontainer_mounts << local_rails_mount if options.dev?

          @devcontainer_mounts
        end

        def devcontainer_forward_ports
          return @devcontainer_forward_ports if @devcontainer_forward_ports

          @devcontainer_forward_ports = [3000]
          @devcontainer_forward_ports << database.port if database.port
          @devcontainer_forward_ports << 6379 if devcontainer_needs_redis?

          @devcontainer_forward_ports
        end

        def devcontainer_needs_redis?
          !(options.skip_action_cable? && options.skip_active_job?)
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
    end
  end
end

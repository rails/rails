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
          @devcontainer_dependencies << db_name_for_devcontainer if db_name_for_devcontainer
          @devcontainer_dependencies
        end

        def devcontainer_variables
          return @devcontainer_variables if @devcontainer_variables

          @devcontainer_variables = {}

          @devcontainer_variables["CAPYBARA_SERVER_PORT"] = "45678" if depends_on_system_test?
          @devcontainer_variables["SELENIUM_HOST"] = "selenium" if depends_on_system_test?
          @devcontainer_variables["REDIS_URL"] = "redis://redis:6379/1" if devcontainer_needs_redis?
          @devcontainer_variables["DB_HOST"] = db_name_for_devcontainer if db_name_for_devcontainer

          @devcontainer_variables
        end

        def devcontainer_volumes
          return @devcontainer_volumes if @devcontainer_volumes

          @devcontainer_volumes = []

          @devcontainer_volumes << "redis-data" if devcontainer_needs_redis?
          @devcontainer_volumes << db_volume_name_for_devcontainer if db_volume_name_for_devcontainer

          @devcontainer_volumes
        end

        def devcontainer_needs_redis?
          !(options.skip_action_cable? && options.skip_active_job?)
        end

        def db_name_for_devcontainer(database = options[:database])
          case database
          when "mysql"          then "mysql"
          when "trilogy"        then "mariadb"
          when "postgresql"     then "postgres"
          end
        end

        def db_volume_name_for_devcontainer(database = options[:database])
          case database
          when "mysql"          then "mysql-data"
          when "trilogy"        then "mariadb-data"
          when "postgresql"     then "postgres-data"
          end
        end

        def db_package_for_dockerfile(database = options[:database])
          case database
          when "mysql"          then "default-libmysqlclient-dev"
          when "postgresql"     then "libpq-dev"
          end
        end

        def devcontainer_db_service_yaml(**options)
          return unless service = db_service_for_devcontainer

          service.to_yaml(**options)[4..-1]
        end

        def db_service_for_devcontainer(database = options[:database])
          case database
          when "mysql"          then mysql_service
          when "trilogy"        then mariadb_service
          when "postgresql"     then postgres_service
          end
        end

        def postgres_service
          {
            "postgres" => {
              "image" => "postgres:16.1",
              "restart" => "unless-stopped",
              "networks" => ["default"],
              "volumes" => ["postgres-data:/var/lib/postgresql/data"],
              "environment" => {
                "POSTGRES_USER" => "postgres",
                "POSTGRES_PASSWORD" => "postgres"
              }
            }
          }
        end

        def mysql_service
          {
            "mysql" => {
              "image" => "mysql/mysql-server:8.0",
              "restart" => "unless-stopped",
              "environment" => {
                "MYSQL_ALLOW_EMPTY_PASSWORD" => true,
                "MYSQL_ROOT_HOST" => "%"
              },
              "volumes" => ["mysql-data:/var/lib/mysql"],
              "networks" => ["default"],
            }
          }
        end

        def mariadb_service
          {
            "mariadb" => {
              "image" => "mariadb:10.5",
              "restart" => "unless-stopped",
              "networks" => ["default"],
              "volumes" => ["mariadb-data:/var/lib/mysql"],
              "environment" => {
                "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => true,
              },
            }
          }
        end

        def db_service_names
          ["mysql", "mariadb", "postgres"]
        end
    end
  end
end

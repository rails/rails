# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/devcontainer/devcontainer_generator"

module Rails
  module Generators
    class DevcontainerGeneratorTest < Rails::Generators::TestCase
      include GeneratorsTestHelper

      def test_creates_devcontainer_files
        run_generator

        assert_file ".devcontainer/compose.yaml"
        assert_file ".devcontainer/Dockerfile"
        assert_file ".devcontainer/devcontainer.json"
        test_common_config
      end

      def test_active_storage_option_default
        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_includes devcontainer_json["features"].keys, "ghcr.io/rails/devcontainer/features/activestorage"
        end
      end

      def test_active_storage_option_skip
        run_generator [ "--skip-active-storage" ]

        test_common_config
        assert_devcontainer_json_file do |devcontainer_json|
          assert_nil devcontainer_json["features"]["ghcr.io/rails/devcontainer/features/activestorage"]
        end
      end

      def test_app_name_option_default
        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "rails_app", devcontainer_json["name"]
        end

        assert_compose_file do |compose|
          assert_equal "rails_app", compose["name"]
        end
      end

      def test_app_name_option
        run_generator ["--app-name", "my-TestApp_name"]

        test_common_config
        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "my-TestApp_name", devcontainer_json["name"]
        end

        assert_compose_file do |compose|
          assert_equal "my-TestApp_name", compose["name"]
        end
      end

      def test_database_default_sqlite3
        run_generator

        assert_no_file "config/database.yml"
        assert_devcontainer_json_file do |devcontainer_json|
          assert_includes devcontainer_json["features"].keys, "ghcr.io/rails/devcontainer/features/sqlite3"
        end
      end

      def test_database_mariadb_mysql
        run_generator [ "--database", "mariadb-mysql" ]

        test_common_config
        assert_no_file "config/database.yml"
        assert_compose_file do |compose|
          expected_mariadb_config = {
            "image" => "mariadb:10.5",
            "restart" => "unless-stopped",
            "networks" => ["default"],
            "volumes" => ["mariadb-data:/var/lib/mysql"],
            "environment" => {
              "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
            },
          }
          assert_equal expected_mariadb_config, compose["services"]["mariadb"]
          assert_includes compose["volumes"].keys, "mariadb-data"
          assert_includes compose["services"]["rails-app"]["depends_on"], "mariadb"
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "mariadb", devcontainer_json["containerEnv"]["DB_HOST"]
          assert_includes devcontainer_json["features"].keys, "ghcr.io/rails/devcontainer/features/mysql-client"
          assert_includes devcontainer_json["forwardPorts"], 3306
        end
      end

      def test_database_mariadb_trilogy
        run_generator [ "--database", "mariadb-trilogy" ]

        test_common_config
        assert_no_file "config/database.yml"
        assert_compose_file do |compose|
          expected_mariadb_config = {
            "image" => "mariadb:10.5",
            "restart" => "unless-stopped",
            "networks" => ["default"],
            "volumes" => ["mariadb-data:/var/lib/mysql"],
            "environment" => {
              "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
            },
          }
          assert_equal expected_mariadb_config, compose["services"]["mariadb"]
          assert_includes compose["volumes"].keys, "mariadb-data"
          assert_includes compose["services"]["rails-app"]["depends_on"], "mariadb"
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "mariadb", devcontainer_json["containerEnv"]["DB_HOST"]
          assert_includes devcontainer_json["forwardPorts"], 3306
        end
      end

      def test_database_mysql
        run_generator [ "--database", "mysql" ]

        test_common_config
        assert_no_file "config/database.yml"
        assert_compose_file do |compose|
          expected_mysql_config = {
            "image" => "mysql/mysql-server:8.0",
            "restart" => "unless-stopped",
            "environment" => {
              "MYSQL_ALLOW_EMPTY_PASSWORD" => "true",
              "MYSQL_ROOT_HOST" => "%"
            },
            "volumes" => ["mysql-data:/var/lib/mysql"],
            "networks" => ["default"],
          }
          assert_equal expected_mysql_config, compose["services"]["mysql"]
          assert_includes compose["volumes"].keys, "mysql-data"
          assert_includes compose["services"]["rails-app"]["depends_on"], "mysql"
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "mysql", devcontainer_json["containerEnv"]["DB_HOST"]
          assert_includes devcontainer_json["features"].keys, "ghcr.io/rails/devcontainer/features/mysql-client"
          assert_includes devcontainer_json["forwardPorts"], 3306
        end
      end

      def test_database_postgresql
        run_generator [ "--database", "postgresql" ]

        test_common_config

        assert_file("config/database.yml") do |db_config|
          assert_match(/host: <%= ENV\["DB_HOST"\] %>/, db_config)
          assert_match(/username: postgres/, db_config)
          assert_match(/password: postgres/, db_config)
        end

        assert_compose_file do |compose|
          expected_postgres_config = {
            "image" => "postgres:16.1",
            "restart" => "unless-stopped",
            "networks" => ["default"],
            "volumes" => ["postgres-data:/var/lib/postgresql/data"],
            "environment" => {
              "POSTGRES_USER" => "postgres",
              "POSTGRES_PASSWORD" => "postgres"
            }
          }
          assert_equal expected_postgres_config, compose["services"]["postgres"]
          assert_includes compose["volumes"].keys, "postgres-data"
          assert_includes compose["services"]["rails-app"]["depends_on"], "postgres"
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "postgres", devcontainer_json["containerEnv"]["DB_HOST"]
          assert_includes devcontainer_json["features"].keys, "ghcr.io/rails/devcontainer/features/postgres-client"
          assert_includes devcontainer_json["forwardPorts"], 5432
        end
      end

      def test_database_trilogy
        run_generator [ "--database", "trilogy" ]

        test_common_config
        assert_no_file "config/database.yml"
        assert_compose_file do |compose|
          expected_mysql_config = {
            "image" => "mysql/mysql-server:8.0",
            "restart" => "unless-stopped",
            "environment" => {
              "MYSQL_ALLOW_EMPTY_PASSWORD" => "true",
              "MYSQL_ROOT_HOST" => "%"
            },
            "volumes" => ["mysql-data:/var/lib/mysql"],
            "networks" => ["default"],
          }
          assert_equal expected_mysql_config, compose["services"]["mysql"]
          assert_includes compose["volumes"].keys, "mysql-data"
          assert_includes compose["services"]["rails-app"]["depends_on"], "mysql"
        end

        assert_devcontainer_json_file do |content|
          assert_equal "mysql", content["containerEnv"]["DB_HOST"]
          assert_includes content["forwardPorts"], 3306
        end
      end

      def test_dev_option_default
        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_nil devcontainer_json["mounts"]
        end
      end

      def test_dev_option
        run_generator ["--dev"]

        test_common_config
        assert_devcontainer_json_file do |devcontainer_json|
          mounts = devcontainer_json["mounts"].sole

          assert_equal "bind", mounts["type"]
          assert_equal Rails::Generators::RAILS_DEV_PATH, mounts["source"]
          assert_equal Rails::Generators::RAILS_DEV_PATH, mounts["target"]
        end
      end

      def test_node_option_default
        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_not_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/node:1"
        end
      end

      def test_node_option
        run_generator ["--node"]

        test_common_config
        assert_devcontainer_json_file do |devcontainer_json|
          assert_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/node:1"
        end
      end

      def test_redis_option_default
        run_generator

        assert_compose_file do |compose|
          assert_includes compose["services"]["rails-app"]["depends_on"], "redis"
          expected_redis_config = {
            "image" => "valkey/valkey:8",
            "restart" => "unless-stopped",
            "volumes" => ["redis-data:/data"]
          }
          assert_equal expected_redis_config, compose["services"]["redis"]
          assert_equal ["redis-data"], compose["volumes"].keys
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "redis://redis:6379/1", devcontainer_json["containerEnv"]["REDIS_URL"]
          assert_includes devcontainer_json["forwardPorts"], 6379
        end
      end

      def test_redis_option_skip
        run_generator ["--skip-redis"]

        test_common_config
        assert_compose_file do |compose|
          assert_not_includes compose["services"]["rails-app"]["depends_on"], "redis"
          assert_nil compose["services"]["redis"]
          assert_nil compose["volumes"]
        end

        assert_devcontainer_json_file do |devcontainer_json|
          assert_not_includes devcontainer_json["forwardPorts"], 6379
        end
      end

      def test_kamal_option_default
        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/docker-outside-of-docker:1"
          assert_equal "$KAMAL_REGISTRY_PASSWORD", devcontainer_json["containerEnv"]["KAMAL_REGISTRY_PASSWORD"]
        end
      end

      def test_kamal_option_skip
        run_generator ["--skip-kamal"]

        assert_devcontainer_json_file do |devcontainer_json|
          assert_not_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/docker-outside-of-docker:1"
          assert_not_includes devcontainer_json["containerEnv"].keys, "KAMAL_REGISTRY_PASSWORD"
        end
      end

      def test_system_test_option_default
        copy_application_system_test_case

        run_generator

        assert_devcontainer_json_file do |devcontainer_json|
          assert_equal "45678", devcontainer_json["containerEnv"]["CAPYBARA_SERVER_PORT"]
          assert_equal "selenium", devcontainer_json["containerEnv"]["SELENIUM_HOST"]
        end

        assert_file("test/application_system_test_case.rb") do |system_test_case|
          assert_match(/^  if ENV\["CAPYBARA_SERVER_PORT"\]/, system_test_case)
          assert_match(/^    served_by host: "rails-app", port: ENV\["CAPYBARA_SERVER_PORT"\]/, system_test_case)
          assert_match(/^    driven_by :selenium, using: :headless_chrome, screen_size: \[ 1400, 1400 \], options: {$/, system_test_case)
          assert_match(/^      browser: :remote,$/, system_test_case)
          assert_match(/^      url: "http:\/\/\#{ENV\["SELENIUM_HOST"\]}:4444"$/, system_test_case)
        end
      end

      def test_system_test_option_does_not_create_new_file
        run_generator ["--system-test"]

        test_common_config
        assert_no_file "test/application_system_test_case.rb"
      end

      def test_system_test_option_skip
        copy_application_system_test_case

        run_generator [ "--skip-system-test", "--force" ]

        test_common_config
        assert_compose_file do |compose|
          assert_not_includes compose["services"]["rails-app"]["depends_on"], "selenium"
          assert_not_includes compose["services"].keys, "selenium"
        end
        assert_devcontainer_json_file do |devcontainer_json|
          assert_nil devcontainer_json["containerEnv"]["CAPYBARA_SERVER_PORT"]
        end
      end

      private
        def test_common_config
          assert_file(".devcontainer/Dockerfile") do |dockerfile|
            assert_match(/ARG RUBY_VERSION=#{RUBY_VERSION}/, dockerfile)
            assert_match(/ENV BINDING="0.0.0.0"/, dockerfile)
          end

          assert_devcontainer_json_file do |devcontainer_json|
            assert_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/github-cli:1"
            assert_includes devcontainer_json["forwardPorts"], 3000
          end

          assert_compose_file do |compose|
            expected_app_config = {
              "build" => {
                "context" => "..",
                "dockerfile" => ".devcontainer/Dockerfile"
              },
              "volumes" => ["../..:/workspaces:cached"],
              "command" => "sleep infinity"
            }
            actual_independent_config = compose["services"]["rails-app"].except("depends_on")
            assert_equal expected_app_config, actual_independent_config
          end
        end
    end
  end
end

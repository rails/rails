# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/db/system/change/change_generator"

module Rails
  module Generators
    module Db
      module System
        class ChangeGeneratorTest < Rails::Generators::TestCase
          include GeneratorsTestHelper

          setup do
            copy_gemfile <<~ENTRY
              # Use sqlite3 as the database for Active Record
              gem "sqlite3"
            ENTRY

            copy_dockerfile
            copy_devcontainer_files
          end

          test "change to invalid database" do
            output = capture(:stderr) do
              run_generator ["--to", "invalid-db"]
            end

            assert_match <<~MSG.squish, output
              Invalid value for --to option.
              Supported preconfigurations are:
              mysql, trilogy, postgresql, sqlite3, mariadb-mysql, mariadb-trilogy.
            MSG
          end

          test "change to postgresql" do
            run_generator ["--to", "postgresql"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: postgresql", content
              assert_match "database: tmp_production", content
              assert_match "host: <%= ENV[\"DB_HOST\"] %>", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use pg as the database for Active Record", content
              assert_match 'gem "pg", "~> 1.1"', content
            end

            assert_file("Dockerfile") do |content|
              assert_match "build-essential git libpq-dev", content
              assert_match "curl libvips postgresql-client", content
            end

            assert_devcontainer_json_file do |content|
              assert_equal "postgres", content["containerEnv"]["DB_HOST"]
              assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/postgres-client"
              assert_not_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/sqlite"
            end

            assert_compose_file do |compose_config|
              assert_includes compose_config["services"]["rails-app"]["depends_on"], "postgres"

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

              assert_equal expected_postgres_config, compose_config["services"]["postgres"]
              assert_includes compose_config["volumes"].keys, "postgres-data"
            end
          end

          test "change to mysql" do
            run_generator ["--to", "mysql"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: mysql2", content
              assert_match "database: tmp_production", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use mysql2 as the database for Active Record", content
              assert_match 'gem "mysql2", "~> 0.5"', content
            end

            assert_file("Dockerfile") do |content|
              assert_match "build-essential default-libmysqlclient-dev git", content
              assert_match "curl default-mysql-client libvips", content
            end

            assert_devcontainer_json_file do |content|
              assert_equal "mysql", content["containerEnv"]["DB_HOST"]
              assert_equal({}, content["features"]["ghcr.io/rails/devcontainer/features/mysql-client"])
            end

            assert_compose_file do |compose_config|
              assert_includes compose_config["services"]["rails-app"]["depends_on"], "mysql"

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

              assert_equal expected_mysql_config, compose_config["services"]["mysql"]
              assert_includes compose_config["volumes"].keys, "mysql-data"
            end
          end

          test "change to sqlite3" do
            run_generator ["--to", "sqlite3"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: sqlite3", content
              assert_match "storage/development.sqlite3", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use sqlite3 as the database for Active Record", content
              assert_match 'gem "sqlite3", ">= 2.1"', content
            end

            assert_file("Dockerfile") do |content|
              assert_match "build-essential git", content
              assert_match "curl libvips sqlite3", content
            end

            assert_devcontainer_json_file do |content|
              assert_not_includes content["containerEnv"].keys, "DB_HOST"
            end
          end

          test "change to trilogy" do
            run_generator ["--to", "trilogy"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: trilogy", content
              assert_match "database: tmp_production", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use trilogy as the database for Active Record", content
              assert_match 'gem "trilogy", "~> 2.7"', content
            end

            assert_file("Dockerfile") do |content|
              assert_match "build-essential git", content
              assert_match "curl libvips", content
              assert_no_match "default-libmysqlclient-dev", content
            end
          end

          test "change to mariadb" do
            run_generator ["--to", "mariadb-mysql"]

            assert_devcontainer_json_file do |content|
              assert_match "mariadb", content["containerEnv"]["DB_HOST"]
            end

            assert_compose_file do |compose_config|
              assert_includes compose_config["services"]["rails-app"]["depends_on"], "mariadb"

              expected_mariadb_config = {
                "image" => "mariadb:10.5",
                "restart" => "unless-stopped",
                "networks" => ["default"],
                "volumes" => ["mariadb-data:/var/lib/mysql"],
                "environment" => {
                  "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
                },
              }

              assert_equal expected_mariadb_config, compose_config["services"]["mariadb"]
              assert_includes compose_config["volumes"].keys, "mariadb-data"
            end
          end

          test "change from versioned gem to other versioned gem" do
            run_generator ["--to", "sqlite3"]
            run_generator ["--to", "mysql", "--force"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: mysql2", content
              assert_match "database: tmp_production", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use mysql2 as the database for Active Record", content
              assert_match 'gem "mysql2", "~> 0.5"', content
            end
          end

          test "change from db with devcontainer service to one without" do
            copy_minimal_devcontainer_compose_file

            run_generator ["--to", "mysql"]
            run_generator ["--to", "sqlite3", "--force"]

            assert_devcontainer_json_file do |content|
              assert_not_includes content["containerEnv"].keys, "DB_HOST"
              assert_not_includes content["features"].keys, "ghcr.io\/rails\/devcontainer\/features\/mysql-client"
            end

            assert_compose_file do |compose_config|
              assert_not_includes compose_config["services"]["rails-app"].keys, "depends_on"
              assert_not_includes compose_config["services"].keys, "mysql"
              assert_not_includes compose_config.keys, "volumes"
            end
          end
        end
      end
    end
  end
end

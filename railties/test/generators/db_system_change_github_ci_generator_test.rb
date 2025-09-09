# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/db/system/change/github/ci_generator"

module Rails
  module Generators
    module Db
      module System
        module Change
          module Github
            class CiGeneratorTest < Rails::Generators::TestCase
              include GeneratorsTestHelper

              setup do
                copy_ci_files
              end

              test "change to invalid database" do
                output = capture(:stderr) do
                  run_generator ["--database", "invalid-db"]
                end

                assert_match <<~MSG.squish, output
                    Expected '--database' to be one of mysql, trilogy, postgresql, sqlite3, mariadb-mysql, mariadb-trilogy; got invalid-db
                MSG
              end

              test "change to postgresql" do
                run_generator ["--database", "postgresql"]

                test_service_config("postgres", {
                  "image" => "postgres",
                  "env" => {
                    "POSTGRES_USER" => "postgres",
                    "POSTGRES_PASSWORD" => "postgres"
                  },
                  "ports" => ["5432:5432"],
                  "options" => "--health-cmd=\"pg_isready\" --health-interval=10s --health-timeout=5s --health-retries=3"
                })
                test_database_url("postgres://postgres:postgres@localhost:5432")
              end

              test "change to mysql" do
                run_generator ["--database", "mysql"]
                test_service_config("mysql", {
                 "image" => "mysql",
                 "env" => {
                   "MYSQL_ALLOW_EMPTY_PASSWORD" => true
                 },
                 "ports" => ["3306:3306"],
                 "options" => "--health-cmd=\"mysqladmin ping\" --health-interval=10s --health-timeout=5s --health-retries=3"
               })
                test_database_url("mysql2://127.0.0.1:3306")
              end

              test "change to sqlite3" do
                run_generator ["--database", "sqlite3"]
                test_no_database_configuration
              end

              test "change to trilogy" do
                run_generator ["--database", "trilogy"]
                test_service_config("mysql", {
                  "image" => "mysql",
                  "env" => {
                    "MYSQL_ALLOW_EMPTY_PASSWORD" => true
                  },
                  "ports" => ["3306:3306"],
                  "options" => "--health-cmd=\"mysqladmin ping\" --health-interval=10s --health-timeout=5s --health-retries=3"
                })
                test_database_url("trilogy://127.0.0.1:3306")
              end

              test "change to mariadb-mysql" do
                run_generator ["--database", "mariadb-mysql"]
                test_no_database_configuration
              end

              test "change to mariadb-trilogy" do
                run_generator ["--database", "mariadb-trilogy"]
                test_no_database_configuration
              end

              test "change from ci with database service" do
                run_generator ["--database", "postgresql"]
                run_generator ["--database", "sqlite3"]

                test_no_database_configuration
              end

              private
                def test_service_config(name, expected_config)
                  assert_ci_file do |ci_config|
                    assert_includes ci_config["jobs"]["test"]["services"].keys, name
                    assert_includes ci_config["jobs"]["system-test"]["services"].keys, name
                    assert_equal expected_config, ci_config["jobs"]["test"]["services"][name]
                    assert_equal expected_config, ci_config["jobs"]["system-test"]["services"][name]
                  end
                end

                def test_database_url(expected_url)
                  assert_ci_file do |ci_config|
                    assert_includes ci_config["jobs"]["test"]["steps"].find { |s| s["name"] == "Run tests" }["env"]["DATABASE_URL"], expected_url
                    assert_includes ci_config["jobs"]["system-test"]["steps"].find { |s| s["name"] == "Run System Tests" }["env"]["DATABASE_URL"], expected_url
                  end
                end

                def test_no_database_configuration
                  assert_ci_file do |ci_config|
                    assert_nil ci_config["jobs"]["test"]["services"]
                    assert_nil ci_config["jobs"]["system-test"]["services"]

                    assert_nil ci_config["jobs"]["test"]["steps"].find { |s| s["name"] == "Run tests" }["env"]["DATABASE_URL"]
                    assert_nil ci_config["jobs"]["system-test"]["steps"].find { |s| s["name"] == "Run System Tests" }["env"]["DATABASE_URL"]
                  end
                end
            end
          end
        end
      end
    end
  end
end

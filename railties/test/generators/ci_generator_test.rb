# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/github/ci_generator"

module Rails
  module Generators
    class Github::CiGeneratorTest < Rails::Generators::TestCase
      include GeneratorsTestHelper

      def test_creates_github_ci_files
        run_generator

        assert_file ".github/workflows/ci.yml"
        assert_file ".github/dependabot.yml"
        test_common_config
      end

      def test_brakeman_option_default
        run_generator

        expected_steps = [
              {
                "name" => "Checkout code",
                "uses" => "actions/checkout@v4"
              },
              {
                "name" => "Set up Ruby",
                "uses" => "ruby/setup-ruby@v1",
                "with" => {
                  "ruby-version" => ".ruby-version",
                  "bundler-cache" => true
                }
              },
              {
                "name" => "Scan for common Rails security vulnerabilities using static analysis",
                "run" => "bin/brakeman --no-pager"
              },
              {
                "name" => "Scan for known security vulnerabilities in gems used",
                "run" => "bin/bundler-audit"
              }
        ]

        assert_ci_file do |ci|
          assert_includes ci["jobs"].keys, "scan_ruby"
          assert_equal "ubuntu-latest", ci["jobs"]["scan_ruby"]["runs-on"]
          assert_equal expected_steps, ci["jobs"]["scan_ruby"]["steps"]
        end
      end

      def test_brakeman_option_skip
        run_generator [ "--skip-brakeman" ]

        test_common_config

        assert_ci_file do |ci|
          assert_not_includes ci["jobs"].keys, "scan_ruby"
        end
      end

      def test_using_importmap_option_default
        run_generator
        expected_steps = [
          {
            "name" => "Checkout code",
            "uses" => "actions/checkout@v4"
          },
          {
            "name" => "Set up Ruby",
            "uses" => "ruby/setup-ruby@v1",
            "with" => {
              "ruby-version" => ".ruby-version",
              "bundler-cache" => true
            }
          },
          {
            "name" => "Scan for security vulnerabilities in JavaScript dependencies",
            "run" => "bin/importmap audit"
          }
        ]

        assert_ci_file do |ci|
          assert_includes ci["jobs"].keys, "scan_js"
          assert_equal "ubuntu-latest", ci["jobs"]["scan_js"]["runs-on"]
          assert_equal expected_steps, ci["jobs"]["scan_js"]["steps"]
        end
      end

      def test_using_importmap_option_skip
        run_generator [ "--skip-importmap" ]

        test_common_config

        assert_ci_file do |ci|
          assert_not_includes ci["jobs"].keys, "scan_js"
        end
      end

      def test_using_skip_rubocop_option_default
        run_generator
        expected_steps = [
          {
            "name" => "Checkout code",
            "uses" => "actions/checkout@v4"
          },
          {
            "name" => "Set up Ruby",
            "uses" => "ruby/setup-ruby@v1",
            "with" => {
              "ruby-version" => ".ruby-version",
              "bundler-cache" => true
            }
          },
          {
            "name" => "Prepare RuboCop cache",
            "uses" => "actions/cache@v4",
            "env" => {
              "DEPENDENCIES_HASH" => "${{ hashFiles('.ruby-version', '**/.rubocop.yml', 'Gemfile.lock') }}"
            },
            "with" => {
              "path" => "${{ env.RUBOCOP_CACHE_ROOT }}",
              "key" => "rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}",
              "restore-keys" => "rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-\n"
            }
          },
          {
            "name" => "Lint code for consistent style",
            "run" => "bin/rubocop -f github"
          }
        ]

        assert_ci_file do |ci|
          assert_includes ci["jobs"].keys, "lint"
          assert_equal "ubuntu-latest", ci["jobs"]["lint"]["runs-on"]
          assert_equal "tmp/rubocop", ci["jobs"]["lint"]["env"]["RUBOCOP_CACHE_ROOT"]
          assert_equal expected_steps, ci["jobs"]["lint"]["steps"]
        end
      end

      def test_using_skip_rubocop_option_skip
        run_generator [ "--skip-rubocop" ]

        test_common_config

        assert_ci_file do |ci|
          assert_not_includes ci["jobs"].keys, "lint"
        end
      end

      def test_using_skip_test_option_default
        run_generator

        assert_ci_file do |ci|
          assert_includes ci["jobs"].keys, "test"
          assert_equal "ubuntu-latest", ci["jobs"]["test"]["runs-on"]
        end
      end

      def test_using_skip_test_option_skip
        run_generator [ "--skip-test" ]

        test_common_config

        assert_ci_file do |ci|
          assert_not_includes ci["jobs"].keys, "test"
        end
      end

      def test_using_skip_system_test_option_default
        run_generator

        assert_ci_file do |ci|
          assert_includes ci["jobs"].keys, "system-test"
          assert_equal "ubuntu-latest", ci["jobs"]["system-test"]["runs-on"]
        end
      end

      def test_using_skip_system_test_option_skip
        run_generator [ "--skip-system-test" ]

        test_common_config

        assert_ci_file do |ci|
          assert_not_includes ci["jobs"].keys, "system-test"
        end
      end

      def test_using_ci_packages_option_default
        run_generator

        assert_ci_file do |ci|
          assert_nil find_step_by(:name, ci, "test", "Install packages")
          assert_nil find_step_by(:name, ci, "system-test", "Install packages")
        end
      end

      def test_using_ci_packages_option
        run_generator [ "--ci-packages", "git", "curl" ]

        assert_ci_file do |ci|
          test_install_packages_step(find_step_by(:name, ci, "test", "Install packages"), "git curl")
          test_install_packages_step(find_step_by(:name, ci, "system-test", "Install packages"), "git curl")
        end
      end

      def test_using_skip_bun_option_default
        run_generator ["--bun-version", "0.1.0"]

        assert_ci_file do |ci|
          test_setup_bun_step(find_step_by(:uses, ci, "test", "oven-sh/setup-bun@v1"), "0.1.0")
          test_setup_bun_step(find_step_by(:uses, ci, "system-test", "oven-sh/setup-bun@v1"), "0.1.0")
        end
      end

      def test_using_skip_bun_option_skip
        run_generator [ "--skip-bun" ]
        assert_ci_file do |ci|
          assert_nil find_step_by(:uses, ci, "test", "oven-sh/setup-bun@v1")
          assert_nil find_step_by(:uses, ci, "system-test", "oven-sh/setup-bun@v1")
        end
      end

      def test_database_default_sqlite3
        run_generator

        assert_ci_file do |ci|
          assert_nil ci["jobs"]["test"]["services"]
          assert_nil ci["jobs"]["system-test"]["services"]
        end

        test_common_tests_steps
      end

      def test_database_mariadb_mysql
        run_generator [ "--database", "mariadb-mysql" ]

        test_common_config
        test_mariadb_config
        test_common_tests_steps
      end
      def test_database_mariadb_trilogy
        run_generator [ "--database", "mariadb-trilogy" ]
        test_common_config
        test_mariadb_config
        test_common_tests_steps
      end

      def test_database_mysql
        run_generator [ "--database", "mysql" ]
        test_common_config
        test_mysql_config
        test_common_tests_steps database_url: "mysql2://127.0.0.1:3306"
      end
      def test_database_postgresql
        run_generator [ "--database", "postgresql" ]
        test_common_config
        test_postgresql_config
        test_common_tests_steps database_url: "postgres://postgres:postgres@localhost:5432"
      end

      def test_database_trilogy
        run_generator [ "--database", "trilogy" ]
        test_common_config
        test_mysql_config
        test_common_tests_steps database_url: "trilogy://127.0.0.1:3306"
      end

      private
        def test_common_config
          assert_file(".github/workflows/ci.yml") do |ci|
            assert_match(/name: CI/, ci)
            assert_match(/on:\n  pull_request:\n  push:\n    branches: \[ main \]/, ci)
            assert_match(/jobs:/, ci)
          end
        end

        def test_mariadb_config
          assert_ci_file do |ci|
            assert_nil ci["jobs"]["test"]["services"]
            assert_nil ci["jobs"]["system-test"]["services"]
          end
        end

        def test_mysql_config
          expected_mysql_config = {
            "image" => "mysql",
            "env" => {
              "MYSQL_ALLOW_EMPTY_PASSWORD" => true
            },
            "ports" => ["3306:3306"],
            "options" => "--health-cmd=\"mysqladmin ping\" --health-interval=10s --health-timeout=5s --health-retries=3"
          }
          assert_ci_file do |ci|
            assert_equal expected_mysql_config, ci["jobs"]["test"]["services"]["mysql"]
            assert_equal expected_mysql_config, ci["jobs"]["system-test"]["services"]["mysql"]
          end
        end

        def test_postgresql_config
          expected_postgresql_config = {
            "image" => "postgres",
            "env" => {
              "POSTGRES_USER" => "postgres",
              "POSTGRES_PASSWORD" => "postgres"
            },
            "ports" => ["5432:5432"],
            "options" => "--health-cmd=\"pg_isready\" --health-interval=10s --health-timeout=5s --health-retries=3"
          }
          assert_ci_file do |ci|
            assert_equal expected_postgresql_config, ci["jobs"]["test"]["services"]["postgres"]
            assert_equal expected_postgresql_config, ci["jobs"]["system-test"]["services"]["postgres"]
          end
        end

        def test_common_tests_steps(**options)
          test_common_test_steps_for("test", **options)
          test_common_test_steps_for("system-test", **options)
        end

        def test_common_test_steps_for(test, **options)
          test = test.to_s.inquiry
          database_url = options.delete(:database_url) || nil
          test_command = test.system? ? "test:system" : "test"
          test_run_name = test.system? ? "Run System tests" : "Run tests"
          test_step = test.system? ? "&& bin/rails system-test" : "test"

          assert_ci_file do |ci|
            test_checkout_code_step(find_step_by(:name, ci, test_step, "Checkout code"))
            test_setup_ruby_step(find_step_by(:name, ci, test_step, "Set up Ruby"))
            test_run_tests_step(find_step_by(:name, ci, test_step, test_run_name), test_command, database_url)
            test_keep_screenshots_step(find_step_by(:name, ci, test_step, "Keep screenshots from failed system tests")) if test.system?
          end
        end

        def find_step_by(type, ci, test_step, step_name)
          ci["jobs"][test_step]["steps"].find { |s| s[type.to_s] == step_name }
        end

        def test_install_packages_step(step, ci_packages)
          assert_equal "Install packages", step["name"]
          assert_equal "sudo apt-get update && sudo apt-get install --no-install-recommends -y #{ci_packages}", step["run"]
        end

        def test_setup_bun_step(step, bun_version = nil)
          assert_equal "oven-sh/setup-bun@v1", step["uses"]
          assert_equal({ "bun-version" => bun_version }, step["with"])
        end

        def test_checkout_code_step(step)
          assert_equal "Checkout code", step["name"]
          assert_equal "actions/checkout@v4", step["uses"]
        end

        def test_setup_ruby_step(step)
          assert_equal "Set up Ruby", step["name"]
          assert_equal "ruby/setup-ruby@v1", step["uses"]
        end

        def test_run_tests_step(step, test_command, database_url)
          assert_equal "Run tests", step["name"]
          assert_equal "bin/rails db:test:prepare #{test_command}", step["run"]
          expected_env = { "RAILS_ENV" => "test" }
          expected_env["DATABASE_URL"] = database_url if database_url
          assert_equal(expected_env, step["env"])
        end

        def test_keep_screenshots_step(step)
          assert_equal "Keep screenshots from failed system tests", step["name"]
          assert_equal "actions/upload-artifact@v4", step["uses"]
          assert_equal({ "name" => "screenshots", "path" => "${{ github.workspace }}/tmp/screenshots", "if-no-files-found" => "ignore" }, step["with"])
        end
    end
  end
end

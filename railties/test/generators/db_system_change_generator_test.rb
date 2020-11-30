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
            copy_gemfile(
              GemfileEntry.new("sqlite3", nil, "Use sqlite3 as the database for Active Record")
            )
          end

          def test_change_to_invalid_database
            output = capture(:stderr) do
              run_generator ["--to", "invalid-db"]
            end

            assert_match <<~MSG.squish, output
              Invalid value for --to option.
              Supported preconfigurations are:
              mysql, postgresql, sqlite3, oracle,
              sqlserver, jdbcmysql, jdbcsqlite3,
              jdbcpostgresql, jdbc.
            MSG
          end

          def test_change_to_postgresql
            run_generator ["--to", "postgresql"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: postgresql", content
              assert_match "database: test_app", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use pg as the database for Active Record", content
              assert_match 'gem "pg", "~> 1.1"', content
            end
          end

          def test_change_to_mysql
            run_generator ["--to", "mysql"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: mysql2", content
              assert_match "database: test_app", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use mysql2 as the database for Active Record", content
              assert_match 'gem "mysql2", "~> 0.5"', content
            end
          end

          def test_change_to_sqlite3
            run_generator ["--to", "sqlite3"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: sqlite3", content
              assert_match "db/development.sqlite3", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use sqlite3 as the database for Active Record", content
              assert_match 'gem "sqlite3", "~> 1.4"', content
            end
          end

          def test_change_from_versioned_gem_to_other_versioned_gem
            run_generator ["--to", "sqlite3"]
            run_generator ["--to", "mysql", "--force"]

            assert_file("config/database.yml") do |content|
              assert_match "adapter: mysql2", content
              assert_match "database: test_app", content
            end

            assert_file("Gemfile") do |content|
              assert_match "# Use mysql2 as the database for Active Record", content
              assert_match 'gem "mysql2", "~> 0.5"', content
            end
          end
        end
      end
    end
  end
end

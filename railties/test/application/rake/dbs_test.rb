# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  module RakeTests
    class RakeDbsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation, EnvHelpers

      def setup
        build_app
        reset_environment_configs
      end

      def teardown
        teardown_app
      end

      def database_url_db_name
        "db/database_url_db.sqlite3"
      end

      def delete_database_config!
        # ensure it's using the DATABASE_URL
        FileUtils.rm_rf("#{app_path}/config/database.yml")
      end

      def db_create_and_drop(expected_database, environment_loaded: true)
        Dir.chdir(app_path) do
          output = rails("db:create")
          assert_match(/Created database/, output)
          assert File.exist?(expected_database)
          yield if block_given?
          assert_equal expected_database, ActiveRecord::Base.connection_db_config.database if environment_loaded
          output = rails("db:drop")
          assert_match(/Dropped database/, output)
          assert_not File.exist?(expected_database)
        end
      end

      test "db:create and db:drop without database URL" do
        require "#{app_path}/config/environment"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
        db_create_and_drop db_config.database
      end

      test "db:create and db:drop with database URL" do
        require "#{app_path}/config/environment"
        delete_database_config!
        with_env DATABASE_URL: "sqlite3:#{database_url_db_name}" do
          db_create_and_drop database_url_db_name
        end
      end

      test "db:create and db:drop with database URL don't use YAML DBs" do
        require "#{app_path}/config/environment"
        delete_database_config!

        File.write("#{app_path}/config/database.yml", <<~YAML)
          test:
            adapter: sqlite3
            database: storage/test.sqlite3

          development:
            adapter: sqlite3
            database: storage/development.sqlite3
        YAML

        with_env DATABASE_URL: "sqlite3:#{database_url_db_name}" do
          with_rails_env "development" do
            db_create_and_drop database_url_db_name do
              assert_not File.exist?("#{app_path}/storage/test.sqlite3")
              assert_not File.exist?("#{app_path}/storage/development.sqlite3")
            end
          end
        end
      end

      test "db:create and db:drop respect environment setting" do
        app_file "config/database.yml", <<-YAML
          <% 1 %>
          development:
            database: <%= Rails.application.config.database %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      ERB_YAML_FIXTURES = {
        "alias ERB" => {
          yaml: <<~YAML,
            sqlite: &sqlite
              adapter: sqlite3
              database: storage/development.sqlite3

            development:
              <<: *<%= ENV["DB"] || "sqlite" %>
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
        "multiline ERB" => {
          yaml: <<~YAML,
            development:
              database: <%=
                Rails.application.config.database
              %>
              adapter: sqlite3
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
        "ERB accessing nested configurations" => {
          yaml: <<~YAML,
            development:
              database: storage/development.sqlite3
              adapter: sqlite3
              other: <%= Rails.application.config.other.value %>
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.other = Struct.new(:value).new(123)
            end
          RUBY
        },
        "conditional statements in ERB" => {
          yaml: <<~YAML,
            development:
            <% if Rails.application.config.database %>
              database: <%= Rails.application.config.database %>
            <% else %>
              database: db/default.sqlite3
            <% end %>
              adapter: sqlite3
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
        "multiple ERB statements on the same line" => {
          yaml: <<~YAML,
            development:
              database: <% if Rails.application.config.database %><%= Rails.application.config.database %><% else %>db/default.sqlite3<% end %>
              adapter: sqlite3
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
        "single-line ERB" => {
          yaml: <<~YAML,
            development:
              <%= Rails.application.config.database ? 'database: storage/development.sqlite3' : 'database: storage/development.sqlite3' %>
              adapter: sqlite3
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
        "key's value as an ERB statement" => {
          yaml: <<~YAML,
            development:
              database: <%= Rails.application.config.database ? 'storage/development.sqlite3' : 'storage/development.sqlite3' %>
              custom_option: <%= ENV['CUSTOM_OPTION'] %>
              adapter: sqlite3
          YAML
          env: <<~RUBY
            Rails.application.configure do
              config.database = "storage/development.sqlite3"
            end
          RUBY
        },
      }.freeze

      test "db:create and db:drop don't raise errors when loading YAML with various ERB formats" do
        ERB_YAML_FIXTURES.each do |name, fixture|
          app_file "config/database.yml", fixture[:yaml]
          app_file "config/environments/development.rb", fixture[:env]
          db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
        end
      end

      def with_database_existing
        Dir.chdir(app_path) do
          rails "db:create"
          yield
          rails "db:drop"
        end
      end

      test "db:create failure because database exists" do
        delete_database_config!
        with_env DATABASE_URL: "sqlite3:#{database_url_db_name}" do
          with_database_existing do
            output = rails("db:create")
            assert_match(/already exists/, output)
          end
        end
      end

      def with_bad_permissions
        Dir.chdir(app_path) do
          FileUtils.chmod("-w", "db")
          yield
          FileUtils.chmod("+w", "db")
        end
      end

      unless Process.uid.zero?
        test "db:create failure because bad permissions" do
          delete_database_config!
          with_env DATABASE_URL: "sqlite3:#{database_url_db_name}" do
            with_bad_permissions do
              output = rails("db:create", allow_failure: true)
              assert_match("Couldn't create '#{database_url_db_name}' database. Please check your configuration.", output)
              assert_equal 1, $?.exitstatus
            end
          end
        end

        test "db:drop failure because bad permissions" do
          delete_database_config!
          with_env DATABASE_URL: "sqlite3:#{database_url_db_name}" do
            with_database_existing do
              with_bad_permissions do
                output = rails("db:drop", allow_failure: true)
                assert_match(/Couldn't drop/, output)
                assert_equal 1, $?.exitstatus
              end
            end
          end
        end
      end

      test "db:drop failure because database does not exist" do
        output = rails("db:drop:_unsafe", "--trace")
        assert_match(/does not exist/, output)
      end
    end
  end
end

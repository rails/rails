# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/method_call_assertions"

module ActiveRecord
  module ConnectionAdapters
    class PostgresqlDbConsoleTest < ActiveRecord::PostgreSQLTestCase
      include ActiveSupport::Testing::MethodCallAssertions

      ENV_VARS = %w(PGUSER PGHOST PGPORT PGPASSWORD PGSSLMODE PGSSLCERT PGSSLKEY PGSSLROOTCERT PGOPTIONS)

      def run(*)
        preserve_pg_env do
          super
        end
      end

      def test_postgresql
        config = make_db_config(adapter: "postgresql", database: "db")

        assert_find_cmd_and_exec_called_with(["psql", "db"]) do
          PostgreSQLAdapter.dbconsole(config)
        end
      end

      def test_postgresql_full
        config = make_db_config(
          adapter: "postgresql",
          database: "db",
          username: "user",
          password: "q1w2e3",
          host: "host",
          port: 5432,
        )

        assert_find_cmd_and_exec_called_with(["psql", "db"]) do
          PostgreSQLAdapter.dbconsole(config)
        end

        assert_equal "user", ENV["PGUSER"]
        assert_equal "host", ENV["PGHOST"]
        assert_equal "5432", ENV["PGPORT"]
        assert_not_equal "q1w2e3", ENV["PGPASSWORD"]
      end

      def test_postgresql_with_ssl
        config = make_db_config(adapter: "postgresql", database: "db", sslmode: "verify-full", sslcert: "client.crt", sslkey: "client.key", sslrootcert: "root.crt")

        assert_find_cmd_and_exec_called_with(["psql", "db"]) do
          PostgreSQLAdapter.dbconsole(config)
        end

        assert_equal "verify-full", ENV["PGSSLMODE"]
        assert_equal "client.crt", ENV["PGSSLCERT"]
        assert_equal "client.key", ENV["PGSSLKEY"]
        assert_equal "root.crt", ENV["PGSSLROOTCERT"]
      end

      def test_postgresql_include_password
        config = make_db_config(adapter: "postgresql", database: "db", username: "user", password: "q1w2e3")

        assert_find_cmd_and_exec_called_with(["psql", "db"]) do
          PostgreSQLAdapter.dbconsole(config, include_password: true)
        end

        assert_equal "user", ENV["PGUSER"]
        assert_equal "q1w2e3", ENV["PGPASSWORD"]
      end

      def test_postgresql_include_variables
        config = make_db_config(adapter: "postgresql", database: "db", variables: { search_path: "my_schema, default, \\my_schema", statement_timeout: 5000, lock_timeout: ":default" })

        assert_find_cmd_and_exec_called_with(["psql", "db"]) do
          PostgreSQLAdapter.dbconsole(config)
        end

        assert_equal "-c search_path=my_schema,\\ default,\\ \\\\my_schema -c statement_timeout=5000", ENV["PGOPTIONS"]
      end

      def test_postgresql_can_use_alternative_cli
        ActiveRecord.database_cli[:postgresql] = "pgcli"
        config = make_db_config(adapter: "postgresql", database: "db")

        assert_find_cmd_and_exec_called_with(["pgcli", "db"]) do
          PostgreSQLAdapter.dbconsole(config)
        end
      ensure
        ActiveRecord.database_cli[:postgresql] = "psql"
      end

      private
        def preserve_pg_env
          old_values = ENV_VARS.map { |var| ENV[var] }
          yield
        ensure
          ENV_VARS.zip(old_values).each { |var, value| ENV[var] = value }
        end

        def make_db_config(config)
          ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", config)
        end

        def assert_find_cmd_and_exec_called_with(args, &block)
          assert_called_with(PostgreSQLAdapter, :find_cmd_and_exec, args, &block)
        end
    end
  end
end

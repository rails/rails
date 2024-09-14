# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/method_call_assertions"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3DbConsoleTest < ActiveRecord::SQLite3TestCase
      include ActiveSupport::Testing::MethodCallAssertions

      def test_sqlite3
        config = make_db_config(adapter: "sqlite3", database: "db.sqlite3")

        assert_find_cmd_and_exec_called_with(["sqlite3", root.join("db.sqlite3").to_s]) do
          SQLite3Adapter.dbconsole(config)
        end
      end

      def test_sqlite3_mode
        config = make_db_config(adapter: "sqlite3", database: "db.sqlite3")

        assert_find_cmd_and_exec_called_with(["sqlite3", "-html", root.join("db.sqlite3").to_s]) do
          SQLite3Adapter.dbconsole(config, mode: "html")
        end
      end

      def test_sqlite3_header
        config = make_db_config(adapter: "sqlite3", database: "db.sqlite3")

        assert_find_cmd_and_exec_called_with(["sqlite3", "-header", root.join("db.sqlite3").to_s]) do
          SQLite3Adapter.dbconsole(config, header: true)
        end
      end

      def test_sqlite3_db_absolute_path
        config = make_db_config(adapter: "sqlite3", database: "/tmp/db.sqlite3")

        assert_find_cmd_and_exec_called_with(["sqlite3", "/tmp/db.sqlite3"]) do
          SQLite3Adapter.dbconsole(config)
        end
      end

      def test_sqlite3_db_with_defined_rails_root
        config = make_db_config(adapter: "sqlite3", database: "config/db.sqlite3")

        Rails.define_singleton_method(:root, &method(:root))

        assert_find_cmd_and_exec_called_with(["sqlite3", Rails.root.join("config/db.sqlite3").to_s]) do
          SQLite3Adapter.dbconsole(config)
        end
      ensure
        Rails.singleton_class.remove_method(:root)
      end

      def test_sqlite3_can_use_alternative_cli
        ActiveRecord.database_cli[:sqlite] = "sqlitecli"
        config = make_db_config(adapter: "sqlite3", database: "config/db.sqlite3", database_cli: "sqlitecli")

        assert_find_cmd_and_exec_called_with(["sqlitecli", root.join("config/db.sqlite3").to_s]) do
          SQLite3Adapter.dbconsole(config)
        end
      ensure
        ActiveRecord.database_cli[:sqlite] = "sqlite3"
      end

      private
        def root
          Pathname(__dir__).join("../../../..")
        end

        def make_db_config(config)
          ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", config)
        end

        def assert_find_cmd_and_exec_called_with(args, &block)
          assert_called_with(SQLite3Adapter, :find_cmd_and_exec, args, &block)
        end
    end
  end
end

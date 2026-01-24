# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/method_call_assertions"

module ActiveRecord
  module ConnectionAdapters
    class Mysql2DbConsoleTest < ActiveRecord::Mysql2TestCase
      include ActiveSupport::Testing::MethodCallAssertions

      def test_mysql
        config = make_db_config(adapter: "mysql2", database: "db")

        assert_find_cmd_and_exec_called_with([%w[mysql mysql5], "db"]) do
          Mysql2Adapter.dbconsole(config)
        end
      end

      def test_mysql_full
        config = make_db_config(
          adapter:   "mysql2",
          database:  "db",
          host:      "localhost",
          port:      1234,
          socket:    "socket",
          username:  "user",
          password:  "qwerty",
          encoding:  "UTF-8",
          sslca:     "/path/to/ca-cert.pem",
          sslcert:   "/path/to/client-cert.pem",
          sslcapath: "/path/to/cacerts",
          sslcipher: "DHE-RSA-AES256-SHA",
          sslkey:    "/path/to/client-key.pem",
          ssl_mode:  "VERIFY_IDENTITY"
        )

        args = [
          %w[mysql mysql5],
          "--host=localhost",
          "--port=1234",
          "--socket=socket",
          "--user=user",
          "--default-character-set=UTF-8",
          "--ssl-ca=/path/to/ca-cert.pem",
          "--ssl-cert=/path/to/client-cert.pem",
          "--ssl-capath=/path/to/cacerts",
          "--ssl-cipher=DHE-RSA-AES256-SHA",
          "--ssl-key=/path/to/client-key.pem",
          "--ssl-mode=VERIFY_IDENTITY",
          "-p", "db"
        ]

        assert_find_cmd_and_exec_called_with(args) do
          Mysql2Adapter.dbconsole(config)
        end
      end

      def test_mysql_include_password
        config = make_db_config(adapter: "mysql2", database: "db", username: "user", password: "qwerty")

        assert_find_cmd_and_exec_called_with([%w[mysql mysql5], "--user=user", "--password=qwerty", "db"]) do
          Mysql2Adapter.dbconsole(config, include_password: true)
        end
      end

      def test_mysql_can_use_alternative_cli
        ActiveRecord.database_cli[:mysql] = "mycli"
        config = make_db_config(adapter: "mysql2", database: "db", database_cli: "mycli")

        assert_find_cmd_and_exec_called_with(["mycli", "db"]) do
          Mysql2Adapter.dbconsole(config)
        end
      ensure
        ActiveRecord.database_cli[:mysql] = %w[mysql mysql5]
      end

      private
        def make_db_config(config)
          ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", config)
        end

        def assert_find_cmd_and_exec_called_with(args, &block)
          assert_called_with(Mysql2Adapter, :find_cmd_and_exec, args, &block)
        end
    end
  end
end
